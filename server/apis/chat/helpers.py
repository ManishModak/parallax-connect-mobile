"""Chat package helper functions."""

import time

from ...models import ChatRequest
from ...logging_setup import get_logger
from ...services.service_manager import service_manager
from ...utils.error_handler import log_debug

logger = get_logger(__name__)


async def perform_smart_search(chat_request: ChatRequest, request_id: str) -> str:
    """Execute smart search logic and return context string."""
    search_router = service_manager.get_search_router()
    web_search_service = service_manager.get_web_search_service()

    try:
        logger.info(f"🧠 [{request_id}] Analyzing search intent...")
        intent_start = time.time()

        intent = await search_router.classify_intent(
            chat_request.prompt, chat_request.messages
        )

        log_debug(
            "Intent classification result",
            request_id,
            {"intent": intent, "duration": time.time() - intent_start},
        )

        if intent.get("needs_search"):
            query = intent.get("search_query", chat_request.prompt)
            logger.info(f"🔍 [{request_id}] Searching web for: {query}")

            search_start = time.time()
            search_results = await web_search_service.search(
                query, depth=chat_request.web_search_depth
            )

            log_debug(
                "Web search completed",
                request_id,
                {
                    "result_count": len(search_results.get("results", [])),
                    "duration": time.time() - search_start,
                },
            )

            if search_results.get("results"):
                search_context = build_search_context(search_results)

                logger.info(
                    f"✅ [{request_id}] Injected {len(search_results['results'])} search results",
                    extra={
                        "extra_data": {
                            "context_preview": search_context[:500] + "..."
                            if len(search_context) > 500
                            else search_context,
                            "context_length": len(search_context),
                            "sources": [r["url"] for r in search_results["results"]],
                        }
                    },
                )
                return search_context
            else:
                logger.info(f"⚠️ [{request_id}] No search results found")
        else:
            logger.info(
                f"⏭️ [{request_id}] Search skipped (Reason: {intent.get('reason')})"
            )

    except Exception as e:
        logger.error(f"❌ [{request_id}] Smart search failed: {e}")

    return ""


def build_search_context(search_results: dict) -> str:
    """Format search results into a reusable context block for the model."""
    results = search_results.get("results", [])
    search_context = "\n\n[WEB SEARCH RESULTS]\n"
    for i, res in enumerate(results):
        search_context += f"Source {i + 1}: {res['title']} ({res['url']})\n"
        if res.get("is_full_content"):
            search_context += f"Content: {res.get('content', '')[:1000]}...\n"
        else:
            search_context += f"Snippet: {res['snippet']}\n"
        search_context += "---\n"
    search_context += "[END WEB SEARCH RESULTS]\n\n"
    return search_context


def build_messages(request: ChatRequest) -> list:
    """Build messages array from request."""
    if request.messages:
        messages = list(request.messages)
        if request.system_prompt:
            messages.insert(0, {"role": "system", "content": request.system_prompt})
    else:
        messages = []
        if request.system_prompt:
            messages.append({"role": "system", "content": request.system_prompt})
        messages.append({"role": "user", "content": request.prompt})
    return messages


def build_payload(request: ChatRequest, messages: list, stream: bool = False) -> dict:
    """Build Parallax API payload."""
    return {
        "model": request.model or "default",
        "messages": messages,
        "stream": stream,
        "max_tokens": request.max_tokens,
        "sampling_params": {
            "temperature": request.temperature,
            "top_p": request.top_p,
            "top_k": request.top_k,
            "repetition_penalty": request.repetition_penalty,
            "presence_penalty": request.presence_penalty,
            "frequency_penalty": request.frequency_penalty,
        },
        "stop": request.stop if request.stop else None,
    }
