"""
Search Router Service.
Determines if a user query requires external information from the web.
"""

import json
import re
import time
from collections import OrderedDict
from typing import Dict, Any, Optional
import threading

from ..services.parallax import ParallaxClient
from ..logging_setup import get_logger
from ..config import DEBUG_MODE, TIMEOUT_FAST
from .http_client import get_async_http_client


class _IntentCacheEntry:
    __slots__ = ("value", "timestamp")

    def __init__(self, value: Dict[str, Any], timestamp: float):
        self.value = value
        self.timestamp = timestamp


class _BoundedTTLCache:
    """Simple bounded LRU cache with TTL semantics for intent results."""

    def __init__(self, max_size: int = 1000, ttl_seconds: float = 120.0):
        self._cache: "OrderedDict[str, _IntentCacheEntry]" = OrderedDict()
        self._max_size = max_size
        self._ttl = ttl_seconds
        self._lock = threading.Lock()

    def get(self, key: str) -> Optional[Dict[str, Any]]:
        with self._lock:
            if key not in self._cache:
                return None
            entry = self._cache[key]
            if time.time() - entry.timestamp > self._ttl:
                del self._cache[key]
                return None
            # Move to end (most recently used)
            self._cache.move_to_end(key)
            return entry.value

    def set(self, key: str, value: Dict[str, Any]) -> None:
        with self._lock:
            now = time.time()
            # Evict oldest if at capacity
            while len(self._cache) >= self._max_size:
                self._cache.popitem(last=False)
            self._cache[key] = _IntentCacheEntry(value=value, timestamp=now)

    def cleanup_expired(self) -> int:
        """Remove all expired entries. Returns count removed."""
        with self._lock:
            now = time.time()
            expired = [
                k for k, v in self._cache.items() if now - v.timestamp > self._ttl
            ]
            for k in expired:
                del self._cache[k]
            return len(expired)


logger = get_logger(__name__)


class SearchRouter:
    """
    Decides if a query needs web search using an LLM call.
    """

    def __init__(
        self,
        parallax_client: ParallaxClient,
        cache_ttl_seconds: float = 120.0,
        cache_max_size: int = 1000,
    ):
        self.client = parallax_client
        self._intent_cache = _BoundedTTLCache(
            max_size=cache_max_size, ttl_seconds=cache_ttl_seconds
        )
        logger.info("🧭 Search Router initialized")

    async def classify_intent(self, query: str, history: list = None) -> Dict[str, Any]:
        """
        Analyze query to see if it needs web search.
        """
        start_time = time.time()

        q_lower = query.lower()

        # Fast exit for document content - NEVER send to web search
        # Documents come prefixed with "Document content:" from the mobile app
        if q_lower.startswith("document content:"):
            logger.info("📄 Detected document submission - skipping web search")
            return {
                "needs_search": False,
                "search_query": "",
                "reason": "Document analysis (no search needed)",
            }

        # Fast exit for excessively long content (likely document/OCR dump)
        # Real search queries are typically under 200 chars
        if len(query) > 500:
            logger.info(
                f"📄 Detected long content ({len(query)} chars) - skipping web search"
            )
            return {
                "needs_search": False,
                "search_query": "",
                "reason": "Long content (likely document/OCR)",
            }

        # Fast exit for obvious non-search queries
        if len(query.split()) < 2 and query.lower() in ["hi", "hello", "test"]:
            return {"needs_search": False, "search_query": "", "reason": "Greeting"}

        # Fast-path for explicit search requests
        if "search for" in q_lower or "look up" in q_lower:
            return {
                "needs_search": True,
                "search_query": query,
                "reason": "Explicit search request",
            }

        # Cache lookup for repeated queries (normalized)
        cache_key = q_lower.strip()
        cached = self._intent_cache.get(cache_key)
        if cached is not None:
            if DEBUG_MODE:
                logger.debug(
                    "🧭 Using cached intent for query",
                    extra={
                        "extra_data": {
                            "query": cache_key,
                        }
                    },
                )
            return cached

        # Use centralized system prompt
        from .prompts import get_prompt

        system_prompt = get_prompt("intent_classifier")

        messages = [{"role": "system", "content": system_prompt}]

        # Add limited history context (last 2 turns) to understand follow-ups
        if history:
            # Simplify history to just content to save tokens
            recent_history = history[-4:]
            messages.extend(recent_history)

        messages.append({"role": "user", "content": query})

        try:
            payload = {
                "model": "default",
                "messages": messages,
                "stream": False,
                "max_tokens": 150,
                "temperature": 0.0,
            }

            http_client = await get_async_http_client()
            resp = await http_client.post(
                self.client.chat_url,
                json=payload,
                timeout=TIMEOUT_FAST,  # Fast timeout for routing
            )

            if resp.status_code == 200:
                data = resp.json()
                content = data["choices"][0]["message"]["content"]

                # Clean potential markdown code blocks
                content = content.replace("```json", "").replace("```", "").strip()

                # Strip <think> tags if present (LLM sometimes includes reasoning)
                # Handle both closed <think>...</think> and unclosed <think>...
                content = re.sub(
                    r"<think>.*?</think>", "", content, flags=re.DOTALL
                ).strip()
                # Handle unclosed think blocks (LLM cut off mid-thinking)
                if content.startswith("<think>"):
                    # Find JSON start after the thinking block
                    json_start = content.find("{")
                    if json_start != -1:
                        content = content[json_start:]
                    else:
                        # No JSON found, use heuristic
                        logger.warning("⚠️ LLM returned only thinking, using heuristic")
                        return self._heuristic_fallback(query)

                try:
                    result = json.loads(content)

                    elapsed = time.time() - start_time
                    if DEBUG_MODE:
                        logger.debug(f"Intent classified in {elapsed:.3f}s: {result}")
                    else:
                        logger.info(
                            f"🧭 Intent classified: {result.get('needs_search')} ({result.get('reason')})"
                        )

                    # Store in cache
                    self._intent_cache.set(cache_key, result)
                    return result
                except json.JSONDecodeError:
                    logger.warning(f"⚠️ Failed to parse router JSON: {content[:100]}...")
                    return self._heuristic_fallback(query)
            else:
                logger.error(f"❌ Router LLM call failed: {resp.status_code}")
                return self._heuristic_fallback(query)

        except Exception as e:
            logger.error(f"❌ Router error: {e}")
            return self._heuristic_fallback(query)

    def _heuristic_fallback(self, query: str) -> Dict[str, Any]:
        """Fallback heuristics if LLM fails - comprehensive trigger detection."""
        q_lower = query.lower()

        # Core search triggers
        core_triggers = [
            "price",
            "cost",
            "worth",
            "news",
            "latest",
            "recent",
            "update",
            "today",
            "yesterday",
            "this week",
            "this month",
            "current",
            "now",
            "live",
            "weather",
            "forecast",
            "search",
            "find",
            "look up",
            "google",
            "who is",
            "what is",
            "where is",
            "when is",
        ]

        # Temporal indicators suggest need for fresh info
        temporal_triggers = [
            "2024",
            "2025",
            "this year",
            "last year",
            "recently",
            "just",
            "new",
            "upcoming",
        ]

        # Comparison queries often need research
        comparison_triggers = [
            "vs",
            "versus",
            "compared to",
            "better than",
            "difference between",
            "which is better",
            "pros and cons",
            "review",
        ]

        # Question words that suggest factual lookup
        question_triggers = [
            "how much",
            "how many",
            "how to",
            "what are",
            "what does",
            "what happened",
            "why did",
            "why is",
            "why are",
        ]

        all_triggers = (
            core_triggers + temporal_triggers + comparison_triggers + question_triggers
        )
        needs_search = any(t in q_lower for t in all_triggers)

        return {
            "needs_search": needs_search,
            "search_query": query,
            "reason": "Heuristic fallback",
        }
