"""
Search Router Service.
Determines if a user query requires external information from the web.
"""

import json
import httpx
import time
from typing import Dict, Any, Optional
from ..services.parallax import ParallaxClient
from ..logging_setup import get_logger
from ..config import DEBUG_MODE

logger = get_logger(__name__)


class SearchRouter:
    """
    Decides if a query needs web search using an LLM call.
    """

    def __init__(self, parallax_client: ParallaxClient):
        self.client = parallax_client
        logger.info("🧭 Search Router initialized")

    async def classify_intent(self, query: str, history: list = None) -> Dict[str, Any]:
        """
        Analyze query to see if it needs web search.
        """
        start_time = time.time()

        # Fast exit for obvious non-search queries
        if len(query.split()) < 2 and query.lower() in ["hi", "hello", "test"]:
            return {"needs_search": False, "search_query": "", "reason": "Greeting"}

        system_prompt = (
            "You are a Search Intent Classifier. Your job is to determine if the user's "
            "latest message requires real-time external information from the web to be answered correctly.\n"
            "Respond ONLY with a JSON object in this format:\n"
            "{\n"
            '  "needs_search": true/false,\n'
            '  "search_query": "optimized keyword query for search engine",\n'
            '  "reason": "brief explanation"\n'
            "}\n"
            "Rules:\n"
            "1. If the user asks for current events, prices, news, or specific facts not in your training data -> needs_search: true.\n"
            "2. If the user asks for coding help, creative writing, summarization of chat, or general knowledge -> needs_search: false.\n"
            "3. If the user explicitly asks to 'search' or 'find' -> needs_search: true.\n"
            "4. Keep the search_query concise (2-5 keywords)."
        )

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

            async with httpx.AsyncClient() as http_client:
                resp = await http_client.post(
                    self.client.chat_url,
                    json=payload,
                    timeout=5.0,  # Fast timeout for routing
                )

                if resp.status_code == 200:
                    data = resp.json()
                    content = data["choices"][0]["message"]["content"]

                    # Clean potential markdown code blocks
                    content = content.replace("```json", "").replace("```", "").strip()

                    try:
                        result = json.loads(content)

                        elapsed = time.time() - start_time
                        if DEBUG_MODE:
                            logger.debug(
                                f"Intent classified in {elapsed:.3f}s: {result}"
                            )
                        else:
                            logger.info(
                                f"🧭 Intent classified: {result.get('needs_search')} ({result.get('reason')})"
                            )

                        return result
                    except json.JSONDecodeError:
                        logger.warning(f"⚠️ Failed to parse router JSON: {content}")
                        return self._heuristic_fallback(query)
                else:
                    logger.error(f"❌ Router LLM call failed: {resp.status_code}")
                    return self._heuristic_fallback(query)

        except Exception as e:
            logger.error(f"❌ Router error: {e}")
            return self._heuristic_fallback(query)

    def _heuristic_fallback(self, query: str) -> Dict[str, Any]:
        """Fallback if LLM fails."""
        q_lower = query.lower()
        triggers = [
            "price",
            "news",
            "latest",
            "today",
            "current",
            "weather",
            "search",
            "find",
            "who is",
        ]
        needs_search = any(t in q_lower for t in triggers)
        return {
            "needs_search": needs_search,
            "search_query": query,
            "reason": "Heuristic fallback",
        }
