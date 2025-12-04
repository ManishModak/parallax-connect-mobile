"""Mock handlers for chat endpoints."""

import asyncio
import json
import re
import time
from datetime import datetime

from ...models import ChatRequest
from ...logging_setup import get_logger
from ...config import DEBUG_MODE
from ...services.service_manager import service_manager
from ...utils.error_handler import log_debug

logger = get_logger(__name__)


async def handle_mock_chat(chat_request: ChatRequest, request_id: str):
    """Handle mock chat request with comprehensive debugging."""
    start_time = time.time()

    logger.info(
        f"📤 [{request_id}] Processing MOCK request",
        extra={
            "request_id": request_id,
            "extra_data": {
                "model": chat_request.model,
                "prompt_length": len(chat_request.prompt),
                "web_search": chat_request.web_search_enabled,
                "mock_mode": True,
            },
        },
    )

    if DEBUG_MODE:
        log_debug(
            "Mock request payload",
            request_id,
            {
                "model": chat_request.model,
                "messages_count": len(chat_request.messages)
                if chat_request.messages
                else 0,
                "max_tokens": chat_request.max_tokens,
                "sampling_params": {
                    "temperature": chat_request.temperature,
                    "top_p": chat_request.top_p,
                },
                "stream": False,
            },
        )

    web_search_service = service_manager.get_web_search_service()
    response_content = ""
    search_metadata = {}

    if "search for" in chat_request.prompt.lower():
        match = re.search(r"search for (.*)", chat_request.prompt, re.IGNORECASE)
        if match:
            query = match.group(1).strip()
            logger.info(f"🔍 [{request_id}] [MOCK] Detected search query: '{query}'")

            search_start = time.time()
            try:
                results = await web_search_service.search(
                    query, depth=chat_request.web_search_depth
                )
                search_duration = time.time() - search_start

                search_metadata = {
                    "query": query,
                    "results_count": len(results.get("results", [])),
                    "duration": search_duration,
                }

                log_debug("Mock search results", request_id, search_metadata)

                if results.get("results"):
                    response_content = f"### 🔍 Search Results for '{query}'\n\n"
                    for i, res in enumerate(results["results"]):
                        response_content += f"**{i + 1}. [{res['title']}]({res['url']})**\n> {res['snippet']}\n\n"
                else:
                    response_content = f"I searched for '{query}' but found no results."

            except Exception as e:
                logger.error(f"❌ [{request_id}] [MOCK] Search error: {e}")
                response_content = f"Search error: {e}"

    if not response_content:
        response_content = f"[MOCK] Server received: '{chat_request.prompt}'. \n\n(Tip: Try 'search for python' to test web search)"

    elapsed = time.time() - start_time

    logger.info(
        f"✅ [{request_id}] [MOCK] Response generated ({elapsed:.2f}s)",
        extra={
            "request_id": request_id,
            "extra_data": {
                "duration_seconds": elapsed,
                "response_length": len(response_content),
                "search_performed": bool(search_metadata),
                **search_metadata,
            },
        },
    )

    return {
        "response": response_content,
        "metadata": {
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": len(response_content.split()),
                "total_tokens": 10 + len(response_content.split()),
            },
            "timing": {
                "duration_ms": int(elapsed * 1000),
                "duration_seconds": round(elapsed, 2),
            },
            "model": "mock-model",
        },
    }


async def mock_stream(request: ChatRequest):
    """Generate mock streaming response with REAL web search capabilities."""
    request_id = datetime.now().strftime("%Y%m%d%H%M%S%f")
    start_time = time.time()

    logger.info(
        f"🌊 [{request_id}] Starting MOCK stream",
        extra={
            "request_id": request_id,
            "extra_data": {
                "model": request.model,
                "stream": True,
                "web_search": request.web_search_enabled,
            },
        },
    )

    web_search_service = service_manager.get_web_search_service()
    total_content = ""

    # 1. Analyze Intent
    yield f"data: {json.dumps({'type': 'thinking', 'content': 'Analyzing search intent...'})}\n\n"
    await asyncio.sleep(0.8)

    search_query = None
    q_lower = request.prompt.lower()

    # Mock intent classification using heuristics
    if len(request.prompt.split()) < 2 and q_lower in ["hi", "hello", "test"]:
        intent = {"needs_search": False, "reason": "Greeting"}
    elif "search for" in q_lower or "look up" in q_lower:
        match = re.search(
            r"(?:search for|look up)\s+(.*)", request.prompt, re.IGNORECASE
        )
        search_query = match.group(1).strip() if match else request.prompt
        intent = {
            "needs_search": True,
            "search_query": search_query,
            "reason": "Explicit search",
        }
    elif request.web_search_enabled:
        triggers = [
            "price",
            "news",
            "latest",
            "today",
            "current",
            "weather",
            "who is",
            "what is",
        ]
        if any(t in q_lower for t in triggers):
            search_query = request.prompt
            intent = {
                "needs_search": True,
                "search_query": search_query,
                "reason": "Heuristic match",
            }
        else:
            intent = {"needs_search": False, "reason": "No triggers found"}
    else:
        intent = {"needs_search": False, "reason": "Web search disabled"}

    log_debug("Mock intent classification", request_id, intent)

    if intent.get("needs_search") and search_query:
        yield f"data: {json.dumps({'type': 'thinking', 'content': f'Searching web for: {search_query}'})}\n\n"
        logger.info(f"🔍 [{request_id}] [MOCK] Stream searching: {search_query}")

        try:
            search_start = time.time()
            search_results = await web_search_service.search(
                search_query, depth=request.web_search_depth
            )
            search_duration = time.time() - search_start

            if search_results.get("results"):
                count = len(search_results["results"])
                log_debug(
                    "Mock stream search success",
                    request_id,
                    {"count": count, "duration": search_duration},
                )

                yield f"data: {json.dumps({'type': 'search_results', 'metadata': {'results': search_results['results'], 'query': search_query}})}\n\n"
                yield f"data: {json.dumps({'type': 'thinking', 'content': f'Found {count} results. Reading content...'})}\n\n"
                await asyncio.sleep(0.8)

                yield f"data: {json.dumps({'type': 'thinking', 'content': 'Synthesizing information from search results...'})}\n\n"
                await asyncio.sleep(1.5)

                response_text = f"### 🔍 Search Results for '{search_query}'\n\n"
                for i, res in enumerate(search_results["results"]):
                    response_text += f"**{i + 1}. [{res['title']}]({res['url']})**\n"
                    response_text += f"> {res['snippet']}\n\n"
                response_text += "\n*(Generated by Parallax Mock Server)*"
            else:
                logger.warning(
                    f"⚠️ [{request_id}] [MOCK] No results for: {search_query}"
                )
                yield f"data: {json.dumps({'type': 'thinking', 'content': 'No relevant results found.'})}\n\n"
                response_text = f"I searched for '{search_query}' but found no results."

        except Exception as e:
            logger.error(f"❌ [{request_id}] [MOCK] Stream search error: {e}")
            yield f"data: {json.dumps({'type': 'thinking', 'content': f'Search failed: {e}'})}\n\n"
            response_text = f"An error occurred while searching: {e}"

    else:
        yield f"data: {json.dumps({'type': 'thinking', 'content': 'No search needed.'})}\n\n"
        log_debug("Mock skipping search", request_id, {"reason": intent.get("reason")})
        await asyncio.sleep(0.4)

        for line in ["Considering the context...", "Formulating response..."]:
            yield f"data: {json.dumps({'type': 'thinking', 'content': line})}\n\n"
            await asyncio.sleep(0.5)

        response_text = (
            f"[MOCK] Server received: '{request.prompt}'.\n\n"
            "**Tip:** To test Web Search UI, try:\n"
            "- `What is the latest AI news?`\n"
            "- `search for python tutorials`"
        )

    # Stream the response content
    for line in response_text.split("\n"):
        for word in line.split(" "):
            chunk = word + " "
            total_content += chunk
            yield f"data: {json.dumps({'type': 'content', 'content': chunk})}\n\n"
            await asyncio.sleep(0.02)
        total_content += "\n"
        yield f"data: {json.dumps({'type': 'content', 'content': chr(10)})}\n\n"

    elapsed = time.time() - start_time
    completion_tokens = len(total_content.split())

    logger.info(
        f"✅ [{request_id}] [MOCK] Stream completed ({elapsed:.2f}s)",
        extra={
            "request_id": request_id,
            "extra_data": {
                "duration_seconds": elapsed,
                "completion_tokens": completion_tokens,
                "search_performed": bool(search_query),
            },
        },
    )

    yield f"data: {json.dumps({'type': 'done', 'metadata': {'prompt_tokens': 10, 'completion_tokens': completion_tokens, 'model': 'mock-model', 'duration_seconds': round(elapsed, 2)}})}\n\n"
