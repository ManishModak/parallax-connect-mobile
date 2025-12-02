"""
Web Search Service.
Implements Normal, Deep, and Deeper search strategies using DuckDuckGo and scraping.
"""

import asyncio
import httpx
import time
from duckduckgo_search import DDGS
from bs4 import BeautifulSoup
from typing import Dict, Any
from ..logging_setup import get_logger
from ..config import DEBUG_MODE, TIMEOUT_FAST

logger = get_logger(__name__)


class WebSearchService:
    """
    Executes web searches with varying depth.
    """

    def __init__(self):
        self.ddgs = DDGS()
        # Headers for scraping to look like a real browser
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
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

    async def _normal_search(self, query: str) -> Dict[str, Any]:
        """
        Normal: 1 Full Visit (Top Result) + 3 Snippets.
        """
        # Fetch results (synchronous DDGS call wrapped in thread if needed, but it's fast)
        results = list(self.ddgs.text(query, max_results=4))

        if not results:
            return {"results": [], "summary": "No results found."}

        # Result #1: Full Visit
        top_result = results[0]
        full_content = await self._scrape_url(top_result["href"], max_words=750)

        processed_results = []

        # Add top result with full content
        processed_results.append(
            {
                "title": top_result["title"],
                "url": top_result["href"],
                "snippet": top_result["body"],
                "content": full_content,
                "is_full_content": True,
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
        Deep: 3 Full Visits (Parallel).
        """
        results = list(self.ddgs.text(query, max_results=3))

        if not results:
            return {"results": [], "summary": "No results found."}

        tasks = [self._scrape_url(r["href"], max_words=1500) for r in results]
        contents = await asyncio.gather(*tasks)

        processed_results = []
        for i, r in enumerate(results):
            processed_results.append(
                {
                    "title": r["title"],
                    "url": r["href"],
                    "snippet": r["body"],
                    "content": contents[i],
                    "is_full_content": True,
                }
            )

        return {"results": processed_results, "depth": "deep"}

    async def _deeper_search(self, query: str) -> Dict[str, Any]:
        """
        Deeper: 4 Broad Visits -> Gap Analysis (Simulated) -> 2 Targeted Visits.
        """
        # Phase 1: Broad Search
        broad_results = list(self.ddgs.text(query, max_results=4))

        if not broad_results:
            return {"results": [], "summary": "No results found."}

        # Scrape top 4
        tasks = [self._scrape_url(r["href"], max_words=2000) for r in broad_results]
        broad_contents = await asyncio.gather(*tasks)

        processed_results = []
        for i, r in enumerate(broad_results):
            processed_results.append(
                {
                    "title": r["title"],
                    "url": r["href"],
                    "snippet": r["body"],
                    "content": broad_contents[i],
                    "is_full_content": True,
                    "phase": "broad",
                }
            )

        # Phase 2: Gap Analysis (Simulated for now)
        targeted_query = f"{query} analysis details"

        # Phase 3: Targeted Search
        targeted_results = list(self.ddgs.text(targeted_query, max_results=2))

        # Filter out duplicates
        existing_urls = {r["href"] for r in broad_results}
        unique_targeted = [
            r for r in targeted_results if r["href"] not in existing_urls
        ]

        if unique_targeted:
            t_tasks = [
                self._scrape_url(r["href"], max_words=1500) for r in unique_targeted
            ]
            t_contents = await asyncio.gather(*t_tasks)

            for i, r in enumerate(unique_targeted):
                processed_results.append(
                    {
                        "title": r["title"],
                        "url": r["href"],
                        "snippet": r["body"],
                        "content": t_contents[i],
                        "is_full_content": True,
                        "phase": "targeted",
                    }
                )

        return {"results": processed_results, "depth": "deeper"}

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
            async with httpx.AsyncClient(follow_redirects=True, verify=False) as client:
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
                            }
                        },
                    )

                return final_text

        except Exception as e:
            if DEBUG_MODE:
                logger.debug(
                    f"⚠️ Failed to scrape {url}: {e}",
                    extra={
                        "extra_data": {
                            "url": url,
                            "error": str(e),
                            "duration": time.time() - scrape_start,
                        }
                    },
                )
            return ""
