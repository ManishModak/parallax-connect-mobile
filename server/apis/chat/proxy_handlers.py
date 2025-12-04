"""Proxy handlers for streaming from Parallax service."""

import json
import time
import httpx

from ...models import ChatRequest
from ...logging_setup import get_logger
from ...config import PARALLAX_SERVICE_URL, TIMEOUT_STREAM_CONNECT, TIMEOUT_STREAM_CHUNK
from ...services.service_manager import service_manager
from ...services.http_client import get_async_http_client
from ...utils.error_handler import log_debug
from .helpers import build_messages, build_payload, build_search_context

logger = get_logger(__name__)


async def stream_from_parallax(request: ChatRequest, request_id: str):
    """Stream response from Parallax service."""
    start_time = time.time()
    search_router = service_manager.get_search_router()
    web_search_service = service_manager.get_web_search_service()

    # Smart Search Logic (Streaming)
    search_context = ""
    if request.web_search_enabled:
        try:
            yield f"data: {json.dumps({'type': 'thinking', 'content': 'Analyzing search intent...'})}\n\n"

            intent = await search_router.classify_intent(
                request.prompt, request.messages
            )

            if intent.get("needs_search"):
                query = intent.get("search_query", request.prompt)
                yield f"data: {json.dumps({'type': 'thinking', 'content': f'Searching web for: {query}'})}\n\n"

                search_results = await web_search_service.search(
                    query, depth=request.web_search_depth
                )

                if search_results.get("results"):
                    result_count = len(search_results["results"])
                    yield f"data: {json.dumps({'type': 'search_results', 'metadata': search_results})}\n\n"
                    yield f"data: {json.dumps({'type': 'thinking', 'content': f'Found {result_count} results. Reading content...'})}\n\n"
                    search_context = build_search_context(search_results)
                else:
                    yield f"data: {json.dumps({'type': 'thinking', 'content': 'No relevant results found.'})}\n\n"
            else:
                yield f"data: {json.dumps({'type': 'thinking', 'content': 'No search needed.'})}\n\n"

        except Exception as e:
            logger.error(f"❌ [{request_id}] Smart search failed: {e}")
            yield f"data: {json.dumps({'type': 'thinking', 'content': f'Search failed: {e}'})}\n\n"

    try:
        # Inject search context
        modified_request = request.model_copy()
        if search_context:
            if modified_request.system_prompt:
                modified_request.system_prompt += search_context
            else:
                modified_request.system_prompt = (
                    "You are a helpful AI assistant.\n" + search_context
                )

        messages = build_messages(modified_request)
        payload = build_payload(modified_request, messages, stream=True)

        log_debug("Streaming payload prepared", request_id, {"payload": payload})

        client = await get_async_http_client()
        async with client.stream(
            "POST",
            PARALLAX_SERVICE_URL,
            json=payload,
            timeout=httpx.Timeout(TIMEOUT_STREAM_CHUNK, connect=TIMEOUT_STREAM_CONNECT),
        ) as response:
            if response.status_code != 200:
                error_text = await response.aread()
                yield f"data: {json.dumps({'type': 'error', 'message': f'Parallax error: {error_text.decode()}'})}\n\n"
                return

            buffer = ""
            in_thinking = False
            prompt_tokens = 0
            completion_tokens = 0

            async for line in response.aiter_lines():
                if not line.strip() or line.startswith(":"):
                    continue

                if line.startswith("data: "):
                    data_str = line[6:]
                    if data_str == "[DONE]":
                        break

                    try:
                        data = json.loads(data_str)
                        choices = data.get("choices", [{}])
                        content = ""
                        if choices:
                            choice = choices[0]
                            delta = choice.get("delta", {})
                            content = (
                                delta.get("content", "")
                                or choice.get("message", {}).get("content", "")
                                or choice.get("messages", {}).get("content", "")
                                or choice.get("text", "")
                            )

                        usage = data.get("usage", {})
                        if usage.get("prompt_tokens"):
                            prompt_tokens = usage["prompt_tokens"]
                        if usage.get("completion_tokens"):
                            completion_tokens = usage["completion_tokens"]

                        if content:
                            buffer += content

                            if "<think>" in buffer and not in_thinking:
                                in_thinking = True
                                buffer = buffer.replace("<think>", "")

                            if "</think>" in buffer and in_thinking:
                                in_thinking = False
                                think_content = buffer.split("</think>")[0]
                                if think_content.strip():
                                    yield f"data: {json.dumps({'type': 'thinking', 'content': think_content})}\n\n"
                                buffer = (
                                    buffer.split("</think>", 1)[1]
                                    if "</think>" in buffer
                                    else ""
                                )
                                continue

                            if in_thinking:
                                if "\n" in buffer or len(buffer) > 50:
                                    yield f"data: {json.dumps({'type': 'thinking', 'content': buffer})}\n\n"
                                    buffer = ""
                            else:
                                if buffer:
                                    yield f"data: {json.dumps({'type': 'content', 'content': buffer})}\n\n"
                                    buffer = ""

                    except json.JSONDecodeError:
                        continue

            if buffer.strip():
                msg_type = "thinking" if in_thinking else "content"
                yield f"data: {json.dumps({'type': msg_type, 'content': buffer})}\n\n"

            elapsed = time.time() - start_time
            logger.info(
                f"✅ [{request_id}] Stream completed ({elapsed:.2f}s)",
                extra={
                    "request_id": request_id,
                    "extra_data": {
                        "duration_seconds": elapsed,
                        "prompt_tokens": prompt_tokens,
                        "completion_tokens": completion_tokens,
                        "total_tokens": prompt_tokens + completion_tokens,
                    },
                },
            )

            yield f"data: {json.dumps({'type': 'done', 'metadata': {'prompt_tokens': prompt_tokens, 'completion_tokens': completion_tokens, 'duration_seconds': round(elapsed, 2)}})}\n\n"

    except httpx.ConnectError as e:
        logger.error(f"🔌 [{request_id}] Cannot connect to Parallax: {e}")
        yield f"data: {json.dumps({'type': 'error', 'message': 'Cannot connect to Parallax. Make sure it is running.'})}\n\n"
    except Exception as e:
        logger.error(f"❌ [{request_id}] Stream error: {e}", exc_info=True)
        yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"
