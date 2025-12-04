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
            "mit.edu", "nytimes.com", "wsj.com", "bloomberg.com",
            "ft.com", "economist.com", "washingtonpost.com"
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
        Normal: 1 Full Visit (Top Result) + 3 Snippets.
        """
        results = await self._search_ddg(query, max_results=4)

        logger.info(
            f"🔎 [AUDIT] Raw DDG Results for '{query}':",
            extra={
                "extra_data": {
                    "count": len(results),
                    "urls": [r.get("href") for r in results],
                    "titles": [r.get("title") for r in results],
                }
            },
        )

        if not results:
            return {"results": [], "summary": "No results found."}

        # Result #1: Full Visit (skip if blocked domain)
        top_result = results[0]
        full_content = ""
        
        if not self._is_blocked_domain(top_result["href"]):
            logger.info(f"⬇️ [AUDIT] Scraping Top Result: {top_result['href']}")
            full_content = await self._scrape_url(top_result["href"], max_words=750)
        else:
            logger.info(f"⏭️ Skipping blocked domain: {top_result['href']}")

        processed_results = []

        # Add top result with full content (or snippet if scrape failed)
        processed_results.append(
            {
                "title": top_result["title"],
                "url": top_result["href"],
                "snippet": top_result["body"],
                "content": full_content if full_content else top_result["body"],
                "is_full_content": bool(full_content),
            }
        )

        # Add others as snippets
        for r in results[1:]:
            processed_results.append(
                {
                    "title": r["title"],
                    "url": r["href"],
                    "snippet": r["body"],
                    "is_full_content": False,
                }
            )

        return {"results": processed_results, "depth": "normal"}

    async def _deep_search(self, query: str) -> Dict[str, Any]:
        """
        Deep: Multi-phase search (Standard Intensity).
        Equivalent to the old 'Deeper' mode.
        """
        if DEBUG_MODE:
            logger.debug("Using DEEP search strategy (Standard Multi-phase)")
            
        return await self._multi_phase_search(
            query,
            config={
                "broad_results": 6,
                "news_results": 3,
                "targeted_queries": ["analysis details"],
                "scrape_limit_broad": 4,
                "scrape_limit_news": 2,
                "scrape_limit_targeted": 2,
                "max_words": 1500,
            },
            depth_name="deep"
        )

    async def _deeper_search(self, query: str) -> Dict[str, Any]:
        """
        Deeper: Ultra-intensive Multi-phase search.
        Significantly increased breadth and depth.
        """
        if DEBUG_MODE:
            logger.debug("Using DEEPER search strategy (Ultra Multi-phase)")

        return await self._multi_phase_search(
            query,
            config={
                "broad_results": 10,
                "news_results": 5,
                "targeted_queries": [
                    "comprehensive analysis", 
                    "future outlook implications",
                    "expert opinions",
                    "statistics and data"
                ],
                "scrape_limit_broad": 6,
                "scrape_limit_news": 4,
                "scrape_limit_targeted": 4,
                "max_words": 3000,
            },
            depth_name="deeper"
        )

    async def _multi_phase_search(self, query: str, config: Dict[str, Any], depth_name: str) -> Dict[str, Any]:
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
        scrapeable_broad = [r for r in broad_results if not self._is_blocked_domain(r["href"])][:config["scrape_limit_broad"]]
        blocked_broad = [r for r in broad_results if self._is_blocked_domain(r["href"])]

        if scrapeable_broad:
            tasks = [self._scrape_url(r["href"], max_words=config["max_words"]) for r in scrapeable_broad]
            broad_contents = await asyncio.gather(*tasks)

            for i, r in enumerate(scrapeable_broad):
                existing_urls.add(r["href"])
                processed_results.append(
                    {
                        "title": r["title"],
                        "url": r["href"],
                        "snippet": r["body"],
                        "content": broad_contents[i] if broad_contents[i] else r["body"],
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
        unique_news = [r for r in news_results if r.get("url") and r["url"] not in existing_urls][:config["scrape_limit_news"]]
        if unique_news:
            news_tasks = [self._scrape_url(r["url"], max_words=config["max_words"]) for r in unique_news 
                         if not self._is_blocked_domain(r["url"])]
            news_contents = await asyncio.gather(*news_tasks) if news_tasks else []
            
            content_idx = 0
            for r in unique_news:
                existing_urls.add(r["url"])
                content = ""
                if not self._is_blocked_domain(r["url"]) and content_idx < len(news_contents):
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
        targeted_queries = [f"{query} {suffix}" for suffix in config["targeted_queries"]]
        
        # Execute targeted searches in parallel
        targeted_tasks = [self._search_ddg(q, max_results=3) for q in targeted_queries]
        targeted_results_lists = await asyncio.gather(*targeted_tasks)
        
        # Flatten results
        all_targeted = [item for sublist in targeted_results_lists for item in sublist]
        
        unique_targeted = [r for r in all_targeted if r["href"] not in existing_urls][:config["scrape_limit_targeted"]]

        if unique_targeted:
            scrapeable_targeted = [r for r in unique_targeted if not self._is_blocked_domain(r["href"])]
            
            if scrapeable_targeted:
                t_tasks = [self._scrape_url(r["href"], max_words=config["max_words"]) for r in scrapeable_targeted]
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
        Scrapes text from a URL, stripping HTML.
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

            # Remove noise
            for tag in soup(
                [
                    "script",
                    "style",
                    "nav",
                    "footer",
                    "header",
                    "aside",
                    "iframe",
                    "form",
                ]
            ):
                tag.decompose()

            text = soup.get_text(separator=" ", strip=True)

            # Truncate
            words = text.split()
            truncated = len(words) > max_words

            if truncated:
                final_text = " ".join(words[:max_words]) + "..."
            else:
                final_text = text

            if DEBUG_MODE:
                logger.debug(
                    f"✅ Scraped {url}",
                    extra={
                        "extra_data": {
                            "url": url,
                            "word_count": len(words),
                            "truncated": truncated,
                            "final_word_count": min(len(words), max_words),
                            "duration_seconds": time.time() - scrape_start,
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
