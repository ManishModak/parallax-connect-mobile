"""
Web Search Service.
Implements Normal, Deep, and Deeper search strategies using DuckDuckGo and scraping.
"""

import asyncio
import httpx
from duckduckgo_search import DDGS
from bs4 import BeautifulSoup
from typing import List, Dict, Any
from ..logging_setup import get_logger

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

    async def search(self, query: str, depth: str = "normal") -> Dict[str, Any]:
        """
        Main entry point for search.
        """
        logger.info(f"🔍 Searching for '{query}' with depth '{depth}'")

        try:
            if depth == "deeper":
                return await self._deeper_search(query)
            elif depth == "deep":
                return await self._deep_search(query)
            else:
                return await self._normal_search(query)
        except Exception as e:
            logger.error(f"❌ Search failed: {e}", exc_info=True)
            return {"error": str(e), "results": []}

    async def _normal_search(self, query: str) -> Dict[str, Any]:
        """
        Normal: 1 Full Visit (Top Result) + 3 Snippets.
        """
        # Fetch results (synchronous DDGS call wrapped in thread if needed, but it's fast)
        # DDGS.text() is a generator
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

        # Phase 2: Gap Analysis (Simulated for now to save latency/complexity)
        # In a full agentic loop, we'd feed `broad_contents` to LLM and ask "What's missing?"
        # Here, we'll just do a targeted search for "latest details" or "analysis" of the query
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
        try:
            async with httpx.AsyncClient(follow_redirects=True, verify=False) as client:
                resp = await client.get(url, headers=self.headers, timeout=5.0)
                if resp.status_code != 200:
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
                if len(words) > max_words:
                    return " ".join(words[:max_words]) + "..."
                return text

        except Exception as e:
            logger.warning(f"⚠️ Failed to scrape {url}: {e}")
            return ""
