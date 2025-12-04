"""
Web Search Service.
Implements Normal, Deep, and Deeper search strategies using DuckDuckGo and scraping.
"""

import asyncio
import time
from typing import Dict, Any, List

from ddgs import DDGS
from bs4 import BeautifulSoup
import httpx

from ..logging_setup import get_logger
from ..config import DEBUG_MODE, TIMEOUT_FAST
from .http_client import get_scraping_http_client

logger = get_logger(__name__)


class WebSearchService:
    """
    Executes web searches with varying depth.
    """

    def __init__(self):
        # Headers for scraping to look like a real browser
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
            "Accept-Language": "en-US,en;q=0.9",
            "Upgrade-Insecure-Requests": "1",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-User": "?1",
        }
        # Domains that commonly block scraping - use snippets only
        self.blocked_domains = {
            "mit.edu",
            "nytimes.com",
            "wsj.com",
            "bloomberg.com",
            "ft.com",
            "economist.com",
            "washingtonpost.com",
        }
        logger.info("🌐 Web Search Service initialized")

    async def search(self, query: str, depth: str = "normal") -> Dict[str, Any]:
        """
        Main entry point for search.
        """
        start_time = time.time()
        logger.info(f"🔍 Searching for '{query}' with depth '{depth}'")

        if DEBUG_MODE:
            logger.debug(
                "Starting web search",
                extra={
                    "extra_data": {
                        "query": query,
                        "depth": depth,
                        "timestamp": start_time,
                    }
                },
            )

        try:
            if depth == "deeper":
                if DEBUG_MODE:
                    logger.debug("Using DEEPER search strategy (4 broad + 2 targeted)")
                result = await self._deeper_search(query)
            elif depth == "deep":
                if DEBUG_MODE:
                    logger.debug("Using DEEP search strategy (3 parallel full visits)")
                result = await self._deep_search(query)
            else:
                if DEBUG_MODE:
                    logger.debug("Using NORMAL search strategy (1 full + 3 snippets)")
                result = await self._normal_search(query)

            elapsed = time.time() - start_time
            if DEBUG_MODE:
                logger.debug(
                    f"Search completed in {elapsed:.2f}s",
                    extra={
                        "extra_data": {
                            "result_count": len(result.get("results", [])),
                            "duration_seconds": elapsed,
                            "depth_used": depth,
                        }
                    },
                )
            return result

        except Exception as e:
            logger.error(f"❌ Search failed: {e}", exc_info=True)
            return {"error": str(e), "results": []}

    def _is_blocked_domain(self, url: str) -> bool:
        """Check if URL is from a domain known to block scraping."""
        for domain in self.blocked_domains:
            if domain in url:
                return True
        return False

    async def _search_ddg(self, query: str, max_results: int = 4) -> List[Dict]:
        """Execute DuckDuckGo search in thread pool to avoid blocking."""
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            None, lambda: list(DDGS().text(query, max_results=max_results))
        )

    async def _search_ddg_news(self, query: str, max_results: int = 4) -> List[Dict]:
        """Execute DuckDuckGo news search for recent content."""
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            None, lambda: list(DDGS().news(query, max_results=max_results))
        )

    async def _normal_search(self, query: str) -> Dict[str, Any]:
        """
        Normal: 2 Full Visits + 2 Snippets + 1 News.
        Balanced speed vs quality.
        """
        # Parallel fetch: web + news
        web_task = self._search_ddg(query, max_results=5)
        news_task = self._search_ddg_news(query, max_results=2)

        results, news_results = await asyncio.gather(web_task, news_task)

        logger.info(
            f"🔎 [AUDIT] Raw DDG Results for '{query}':",
            extra={
                "extra_data": {
                    "web_count": len(results),
                    "news_count": len(news_results),
                    "urls": [r.get("href") for r in results],
                }
            },
        )

        if not results and not news_results:
            return {"results": [], "summary": "No results found."}

        processed_results = []
        existing_urls = set()

        # Scrape top 2 results in parallel
        scrapeable = [r for r in results[:4] if not self._is_blocked_domain(r["href"])][
            :2
        ]

        if scrapeable:
            scrape_tasks = [
                self._scrape_url(r["href"], max_words=1000) for r in scrapeable
            ]
            contents = await asyncio.gather(*scrape_tasks)

            for i, r in enumerate(scrapeable):
                existing_urls.add(r["href"])
                processed_results.append(
                    {
                        "title": r["title"],
                        "url": r["href"],
                        "snippet": r["body"],
                        "content": contents[i] if contents[i] else r["body"],
                        "is_full_content": bool(contents[i]),
                        "phase": "primary",
                    }
                )

        # Add 2 more as snippets
        snippet_count = 0
        for r in results:
            if r["href"] not in existing_urls and snippet_count < 2:
                existing_urls.add(r["href"])
                processed_results.append(
                    {
                        "title": r["title"],
                        "url": r["href"],
                        "snippet": r["body"],
                        "is_full_content": False,
                        "phase": "snippet",
                    }
                )
                snippet_count += 1

        # Add 1 news result if available
        for news in news_results[:1]:
            if news.get("url") and news["url"] not in existing_urls:
                processed_results.append(
                    {
                        "title": news.get("title", ""),
                        "url": news["url"],
                        "snippet": news.get("body", news.get("excerpt", "")),
                        "is_full_content": False,
                        "phase": "news",
                        "date": news.get("date", ""),
                    }
                )

        return {"results": processed_results, "depth": "normal"}

    async def _deep_search(self, query: str) -> Dict[str, Any]:
        """
        Deep: Multi-phase search with dynamic targeted queries.
        Good balance of breadth and depth.
        """
        if DEBUG_MODE:
            logger.debug("Using DEEP search strategy (Enhanced Multi-phase)")

        return await self._multi_phase_search(
            query,
            config={
                "broad_results": 8,
                "news_results": 4,
                "targeted_queries": [
                    "detailed analysis",
                    "explained",
                    "latest updates",
                ],
                "scrape_limit_broad": 5,
                "scrape_limit_news": 3,
                "scrape_limit_targeted": 3,
                "max_words": 2000,
            },
            depth_name="deep",
        )

    async def _deeper_search(self, query: str) -> Dict[str, Any]:
        """
        Deeper: Ultra-intensive Multi-phase search.
        Maximum breadth and depth for comprehensive research.
        """
        if DEBUG_MODE:
            logger.debug("Using DEEPER search strategy (Maximum Intensity)")

        return await self._multi_phase_search(
            query,
            config={
                "broad_results": 12,
                "news_results": 6,
                "targeted_queries": [
                    "comprehensive analysis",
                    "expert opinions",
                    "statistics data facts",
                    "comparison pros cons",
                    "future predictions outlook",
                    "recent developments",
                ],
                "scrape_limit_broad": 8,
                "scrape_limit_news": 5,
                "scrape_limit_targeted": 6,
                "max_words": 3500,
            },
            depth_name="deeper",
        )

    async def _multi_phase_search(
        self, query: str, config: Dict[str, Any], depth_name: str
    ) -> Dict[str, Any]:
        """
        Executes a configurable multi-phase search strategy.
        """
        # Phase 1: Broad Web Search + News Search in parallel
        broad_task = self._search_ddg(query, max_results=config["broad_results"])
        news_task = self._search_ddg_news(query, max_results=config["news_results"])

        broad_results, news_results = await asyncio.gather(broad_task, news_task)

        logger.info(
            f"🔎 [AUDIT] Raw DDG Results ({depth_name} - Broad) for '{query}':",
            extra={
                "extra_data": {
                    "web_count": len(broad_results),
                    "news_count": len(news_results),
                    "urls": [r.get("href") for r in broad_results],
                }
            },
        )

        if not broad_results and not news_results:
            return {"results": [], "summary": "No results found."}

        processed_results = []
        existing_urls = set()

        # Process broad results
        scrapeable_broad = [
            r for r in broad_results if not self._is_blocked_domain(r["href"])
        ][: config["scrape_limit_broad"]]
        blocked_broad = [r for r in broad_results if self._is_blocked_domain(r["href"])]

        if scrapeable_broad:
            tasks = [
                self._scrape_url(r["href"], max_words=config["max_words"])
                for r in scrapeable_broad
            ]
            broad_contents = await asyncio.gather(*tasks)

            for i, r in enumerate(scrapeable_broad):
                existing_urls.add(r["href"])
                processed_results.append(
                    {
                        "title": r["title"],
                        "url": r["href"],
                        "snippet": r["body"],
                        "content": broad_contents[i]
                        if broad_contents[i]
                        else r["body"],
                        "is_full_content": bool(broad_contents[i]),
                        "phase": "broad",
                    }
                )

        # Add blocked domains as snippets
        for r in blocked_broad[:2]:
            if r["href"] not in existing_urls:
                existing_urls.add(r["href"])
                processed_results.append(
                    {
                        "title": r["title"],
                        "url": r["href"],
                        "snippet": r["body"],
                        "is_full_content": False,
                        "phase": "broad",
                    }
                )

        # Process news results
        unique_news = [
            r for r in news_results if r.get("url") and r["url"] not in existing_urls
        ][: config["scrape_limit_news"]]
        if unique_news:
            news_tasks = [
                self._scrape_url(r["url"], max_words=config["max_words"])
                for r in unique_news
                if not self._is_blocked_domain(r["url"])
            ]
            news_contents = await asyncio.gather(*news_tasks) if news_tasks else []

            content_idx = 0
            for r in unique_news:
                existing_urls.add(r["url"])
                content = ""
                if not self._is_blocked_domain(r["url"]) and content_idx < len(
                    news_contents
                ):
                    content = news_contents[content_idx]
                    content_idx += 1

                processed_results.append(
                    {
                        "title": r.get("title", ""),
                        "url": r["url"],
                        "snippet": r.get("body", r.get("excerpt", "")),
                        "content": content if content else r.get("body", ""),
                        "is_full_content": bool(content),
                        "phase": "news",
                        "date": r.get("date", ""),
                    }
                )

        # Phase 3: Targeted Search
        targeted_queries = [
            f"{query} {suffix}" for suffix in config["targeted_queries"]
        ]

        # Execute targeted searches in parallel
        targeted_tasks = [self._search_ddg(q, max_results=3) for q in targeted_queries]
        targeted_results_lists = await asyncio.gather(*targeted_tasks)

        # Flatten results
        all_targeted = [item for sublist in targeted_results_lists for item in sublist]

        unique_targeted = [r for r in all_targeted if r["href"] not in existing_urls][
            : config["scrape_limit_targeted"]
        ]

        if unique_targeted:
            scrapeable_targeted = [
                r for r in unique_targeted if not self._is_blocked_domain(r["href"])
            ]

            if scrapeable_targeted:
                t_tasks = [
                    self._scrape_url(r["href"], max_words=config["max_words"])
                    for r in scrapeable_targeted
                ]
                t_contents = await asyncio.gather(*t_tasks)

                for i, r in enumerate(scrapeable_targeted):
                    processed_results.append(
                        {
                            "title": r["title"],
                            "url": r["href"],
                            "snippet": r["body"],
                            "content": t_contents[i] if t_contents[i] else r["body"],
                            "is_full_content": bool(t_contents[i]),
                            "phase": "targeted",
                        }
                    )

        return {"results": processed_results, "depth": depth_name}

    async def _scrape_url(self, url: str, max_words: int = 1000) -> str:
        """
        Scrapes text from a URL with intelligent content extraction.
        - Prioritizes article/main content
        - Removes noise elements (ads, sidebars, comments)
        - Truncates at sentence boundaries
        - Extracts metadata when available
        """
        scrape_start = time.time()
        if DEBUG_MODE:
            logger.debug(
                f"Starting scrape: {url}",
                extra={"extra_data": {"url": url, "max_words": max_words}},
            )

        try:
            client = await get_scraping_http_client()
            resp = await client.get(url, headers=self.headers, timeout=TIMEOUT_FAST)
            if resp.status_code != 200:
                if DEBUG_MODE:
                    logger.debug(
                        f"Scrape failed for {url}: Status {resp.status_code}",
                        extra={
                            "extra_data": {
                                "url": url,
                                "status_code": resp.status_code,
                                "duration": time.time() - scrape_start,
                            }
                        },
                    )
                return ""

            soup = BeautifulSoup(resp.text, "lxml")

            # Extract metadata before cleaning
            metadata_parts = []

            # Try to get publish date
            time_el = soup.find("time")
            if time_el and time_el.get("datetime"):
                metadata_parts.append(f"Published: {time_el['datetime'][:10]}")
            else:
                meta_date = soup.find("meta", property="article:published_time")
                if meta_date and meta_date.get("content"):
                    metadata_parts.append(f"Published: {meta_date['content'][:10]}")

            # Try to get author
            meta_author = soup.find("meta", attrs={"name": "author"})
            if meta_author and meta_author.get("content"):
                metadata_parts.append(f"Author: {meta_author['content']}")

            # Extended noise tag removal
            noise_tags = [
                "script",
                "style",
                "nav",
                "footer",
                "header",
                "aside",
                "iframe",
                "form",
                "noscript",
                "svg",
                "button",
                "input",
                "select",
                "textarea",
                "label",
                "menu",
                "menuitem",
                "dialog",
                "template",
                "canvas",
                "video",
                "audio",
                "source",
                "picture",
            ]
            for tag in soup(noise_tags):
                tag.decompose()

            # Remove elements by class patterns (ads, sidebars, comments, etc.)
            noise_class_patterns = [
                "ad",
                "ads",
                "advert",
                "advertisement",
                "banner",
                "sidebar",
                "side-bar",
                "side_bar",
                "comment",
                "comments",
                "discussion",
                "share",
                "sharing",
                "social",
                "related",
                "recommended",
                "suggestions",
                "newsletter",
                "subscribe",
                "signup",
                "popup",
                "modal",
                "overlay",
                "cookie",
                "gdpr",
                "consent",
                "navigation",
                "breadcrumb",
                "menu",
            ]
            for el in soup.find_all(class_=True):
                classes = " ".join(el.get("class", [])).lower()
                if any(pattern in classes for pattern in noise_class_patterns):
                    el.decompose()

            # Prioritize article content containers
            content = None
            content_selectors = [
                "article",
                "main",
                "[role='main']",
                ".article-content",
                ".article-body",
                ".post-content",
                ".entry-content",
                ".content-body",
                "#article-body",
                "#content",
                ".story-body",
            ]

            for selector in content_selectors:
                try:
                    content = soup.select_one(selector)
                    if content and len(content.get_text(strip=True)) > 200:
                        break
                except Exception:
                    pass
                content = None

            # Fallback to body if no article container found
            if not content:
                content = soup.body if soup.body else soup

            # Final safety check
            if content is None:
                logger.warning(f"⚠️ No parseable content in {url}")
                return ""

            text = content.get_text(separator=" ", strip=True)

            # Intelligent truncation at sentence boundaries
            words = text.split()
            if len(words) > max_words:
                # Find a sentence boundary near max_words
                truncated_text = " ".join(words[:max_words])

                # Try to end at a sentence boundary
                sentence_end = max(
                    truncated_text.rfind(". "),
                    truncated_text.rfind("! "),
                    truncated_text.rfind("? "),
                )

                if sentence_end > len(truncated_text) * 0.7:  # Only if not too far back
                    final_text = truncated_text[: sentence_end + 1]
                else:
                    final_text = truncated_text + "..."
            else:
                final_text = text

            # Prepend metadata if available
            if metadata_parts:
                final_text = f"[{' | '.join(metadata_parts)}]\n\n{final_text}"

            if DEBUG_MODE:
                logger.debug(
                    f"✅ Scraped {url}",
                    extra={
                        "extra_data": {
                            "url": url,
                            "word_count": len(words),
                            "truncated": len(words) > max_words,
                            "final_word_count": len(final_text.split()),
                            "duration_seconds": time.time() - scrape_start,
                            "has_metadata": bool(metadata_parts),
                            "preview": final_text[:200] + "..."
                            if final_text
                            else "No content",
                        }
                    },
                )

            # Always log scrape summary in INFO
            logger.info(
                f"📄 Scraped {len(words)} words from {url} ({time.time() - scrape_start:.2f}s)"
            )

            return final_text

        except httpx.ConnectError as e:
            # Surface SSL / connection issues clearly for debugging, but don't fail the request.
            logger.warning(f"⚠️ Connection/SSL error while scraping {url}: {e}")
            return ""
        except Exception as e:
            logger.warning(f"⚠️ Failed to scrape {url}: {e}")
            return ""
