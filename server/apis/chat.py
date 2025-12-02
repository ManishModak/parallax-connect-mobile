"""Chat endpoints (sync and streaming)."""

import asyncio
import json
import re
import time
from datetime import datetime
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, Request
from fastapi.responses import StreamingResponse
import httpx

from ..auth import check_password
from ..config import SERVER_MODE, PARALLAX_SERVICE_URL, DEBUG_MODE, TIMEOUT_DEFAULT
from ..models import ChatRequest
from ..logging_setup import get_logger
from ..services.service_manager import service_manager
from ..utils.error_handler import handle_service_error, log_debug
from ..utils.request_validator import validate_chat_request

router = APIRouter()
logger = get_logger(__name__)


@router.post("/chat")
async def chat_endpoint(
    request: Request, chat_request: ChatRequest, _: bool = Depends(check_password)
):
    """Synchronous chat endpoint."""
    request_id = getattr(
        request.state, "request_id", datetime.now().strftime("%Y%m%d%H%M%S%f")
    )
    start_time = time.time()

    logger.info(
        f"📝 [{request_id}] Chat request: {chat_request.model}",
        extra={
            "request_id": request_id,
            "extra_data": {
                "model": chat_request.model,
                "max_tokens": chat_request.max_tokens,
                "stream": False,
                "prompt_length": len(chat_request.prompt),
                "web_search": chat_request.web_search_enabled,
            },
        },
    )

    # Log full request in debug mode
    log_debug("Full chat request payload", request_id, chat_request.dict())

    # Validate request
    validate_chat_request(
        prompt=chat_request.prompt,
        system_prompt=chat_request.system_prompt,
        messages=chat_request.messages,
        request_id=request_id,
    )

    if SERVER_MODE == "MOCK":
        return await _handle_mock_chat(chat_request, request_id)

    # Smart Search Logic
    search_context = ""
    if chat_request.web_search_enabled:
        search_context = await _perform_smart_search(chat_request, request_id)

    # PROXY mode
    try:
        logger.info(
            f"🔄 [{request_id}] Forwarding to Parallax at {PARALLAX_SERVICE_URL}"
        )

        async with httpx.AsyncClient() as client:
            # Inject search context into system prompt or user message
            modified_request = chat_request.copy()
            if search_context:
                if modified_request.system_prompt:
                    modified_request.system_prompt += search_context
                else:
                    modified_request.system_prompt = (
                        "You are a helpful AI assistant.\n" + search_context
                    )

            messages = _build_messages(modified_request)
            payload = _build_payload(modified_request, messages, stream=False)

            log_debug(
                "Proxy payload prepared",
                request_id,
                {"payload_keys": list(payload.keys())},
            )

            if DEBUG_MODE:
                # Log full payload in debug mode for troubleshooting
                logger.debug(
                    f"[{request_id}] Full Parallax request payload",
                    extra={
                        "request_id": request_id,
                        "extra_data": {
                            "model": payload.get("model"),
                            "message_count": len(payload.get("messages", [])),
                            "max_tokens": payload.get("max_tokens"),
                            "sampling_params": payload.get("sampling_params"),
                            "stream": payload.get("stream"),
                            # Include first/last messages for context
                            "first_message": payload.get("messages", [{}])[0]
                            if payload.get("messages")
                            else None,
                            "last_message": payload.get("messages", [{}])[-1]
                            if payload.get("messages")
                            else None,
                        },
                    },
                )

            resp = await client.post(
                PARALLAX_SERVICE_URL, json=payload, timeout=TIMEOUT_DEFAULT
            )

            if resp.status_code != 200:
                raise HTTPException(
                    status_code=resp.status_code, detail=f"Parallax Error: {resp.text}"
                )

            data = resp.json()
            choice = data["choices"][0]
            raw_content = (
                choice.get("messages", {}).get("content")
                or choice.get("message", {}).get("content")
                or ""
            )

            # Clean response - remove <think>...</think> tags
            content = re.sub(
                r"<think>.*?</think>", "", raw_content, flags=re.DOTALL
            ).strip()
            if not content:
                content = raw_content

            usage = data.get("usage", {})
            elapsed = time.time() - start_time

            logger.info(
                f"✅ [{request_id}] Response received ({elapsed:.2f}s)",
                extra={
                    "request_id": request_id,
                    "extra_data": {
                        "duration_seconds": elapsed,
                        "prompt_tokens": usage.get("prompt_tokens", 0),
                        "completion_tokens": usage.get("completion_tokens", 0),
                        "total_tokens": usage.get("total_tokens", 0),
                        "model": data.get("model", "default"),
                    },
                },
            )

            return {
                "response": content,
                "metadata": {
                    "usage": {
                        "prompt_tokens": usage.get("prompt_tokens", 0),
                        "completion_tokens": usage.get("completion_tokens", 0),
                        "total_tokens": usage.get("total_tokens", 0),
                    },
                    "timing": {
                        "duration_ms": int(elapsed * 1000),
                        "duration_seconds": round(elapsed, 2),
                    },
                    "model": data.get("model", "default"),
                },
            }

    except Exception as e:
        return handle_service_error(e, "Chat Endpoint", request_id)


@router.post("/chat/stream")
async def chat_stream_endpoint(
    request: Request, chat_request: ChatRequest, _: bool = Depends(check_password)
):
    """Streaming chat endpoint that returns Server-Sent Events (SSE)."""
    request_id = getattr(
        request.state, "request_id", datetime.now().strftime("%Y%m%d%H%M%S%f")
    )

    logger.info(
        f"🌊 [{request_id}] Streaming request: {chat_request.model}",
        extra={
            "request_id": request_id,
            "extra_data": {
                "model": chat_request.model,
                "stream": True,
                "prompt_length": len(chat_request.prompt),
                "web_search": chat_request.web_search_enabled,
            },
        },
    )

    log_debug("Full stream request payload", request_id, chat_request.dict())

    # Validate request
    validate_chat_request(
        prompt=chat_request.prompt,
        system_prompt=chat_request.system_prompt,
        messages=chat_request.messages,
        request_id=request_id,
    )

    if SERVER_MODE == "MOCK":
        return StreamingResponse(
            _mock_stream(chat_request), media_type="text/event-stream"
        )

    return StreamingResponse(
        _stream_from_parallax(chat_request, request_id),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.post("/vision")
async def vision_endpoint(
    image: UploadFile = File(...),
    prompt: str = Form(...),
    _: bool = Depends(check_password),
):
    """Vision endpoint (not yet implemented in Parallax)."""
    request_id = datetime.now().strftime("%Y%m%d%H%M%S%f")
    logger.info(f"📸 [{request_id}] Vision request: {prompt[:50]}...")

    if SERVER_MODE == "MOCK":
        return {
            "response": f"[MOCK] Vision Analysis: I see a simulated image. Prompt: {prompt}"
        }

    logger.warning(f"⚠️ [{request_id}] Vision proxy not yet implemented")
    return {"response": "[PROXY] Vision not yet implemented in Parallax API wrapper."}


# Helper functions


async def _perform_smart_search(chat_request: ChatRequest, request_id: str) -> str:
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
                # Format results for context
                search_context = "\n\n[WEB SEARCH RESULTS]\n"
                for i, res in enumerate(search_results["results"]):
                    search_context += f"Source {i + 1}: {res['title']} ({res['url']})\n"
                    if res.get("is_full_content"):
                        search_context += (
                            f"Content: {res.get('content', '')[:1000]}...\n"
                        )
                    else:
                        search_context += f"Snippet: {res['snippet']}\n"
                    search_context += "---\n"
                search_context += "[END WEB SEARCH RESULTS]\n\n"

                logger.info(
                    f"✅ [{request_id}] Injected {len(search_results['results'])} search results"
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
        # Don't fail the whole request, just log and continue without search context

    return ""


def _build_messages(request: ChatRequest) -> list:
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


def _build_payload(request: ChatRequest, messages: list, stream: bool = False) -> dict:
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


async def _handle_mock_chat(chat_request: ChatRequest, request_id: str):
    """Handle mock chat request."""
    logger.info(f"📤 [{request_id}] Returning MOCK response")

    web_search_service = service_manager.get_web_search_service()

    # Check for search keyword
    if "search for" in chat_request.prompt.lower():
        match = re.search(r"search for (.*)", chat_request.prompt, re.IGNORECASE)
        if match:
            query = match.group(1).strip()
            try:
                results = await web_search_service.search(query, depth="normal")
                if results.get("results"):
                    response_text = f"### 🔍 Search Results for '{query}'\n\n"
                    for i, res in enumerate(results["results"]):
                        response_text += f"**{i + 1}. [{res['title']}]({res['url']})**\n> {res['snippet']}\n\n"
                    return {"response": response_text}
                else:
                    return {
                        "response": f"I searched for '{query}' but found no results."
                    }
            except Exception as e:
                return {"response": f"Search error: {e}"}

    return {
        "response": f"[MOCK] Server received: '{chat_request.prompt}'. \n\n(Tip: Try 'search for python' to test web search)"
    }


async def _mock_stream(request: ChatRequest):
    """Generate mock streaming response with REAL web search capabilities."""
    web_search_service = service_manager.get_web_search_service()

    # 1. Analyze Intent (Mocked)
    yield f"data: {json.dumps({'type': 'thinking', 'content': 'Analyzing intent...'})}\n\n"
    await asyncio.sleep(1.0)

    search_query = None
    # Check for explicit search keyword
    if "search for" in request.prompt.lower():
        match = re.search(r"search for (.*)", request.prompt, re.IGNORECASE)
        if match:
            search_query = match.group(1).strip()

    if search_query:
        # 2. Perform Real Search
        yield f"data: {json.dumps({'type': 'thinking', 'content': f'Searching for "{search_query}"...'})}\n\n"

        try:
            # Execute actual search service
            search_results = await web_search_service.search(
                search_query, depth="normal"
            )

            if search_results.get("results"):
                count = len(search_results["results"])
                yield f"data: {json.dumps({'type': 'thinking', 'content': f'Found {count} results.'})}\n\n"
                await asyncio.sleep(1.0)

                # 3. Actual Thinking (Triggers standard thinking UI)
                yield f"data: {json.dumps({'type': 'thinking', 'content': 'Synthesizing information from search results...'})}\n\n"
                await asyncio.sleep(1.5)

                # Format results as the response
                response_text = f"### 🔍 Search Results for '{search_query}'\n\n"
                for i, res in enumerate(search_results["results"]):
                    response_text += f"**{i + 1}. [{res['title']}]({res['url']})**\n"
                    response_text += f"> {res['snippet']}\n\n"

                response_text += "\n*(Generated by Parallax Mock Server)*"
            else:
                yield f"data: {json.dumps({'type': 'thinking', 'content': 'No results found.'})}\n\n"
                response_text = f"I searched for '{search_query}' but found no results."

        except Exception as e:
            yield f"data: {json.dumps({'type': 'thinking', 'content': f'Search error: {e}'})}\n\n"
            response_text = f"An error occurred while searching: {e}"

    else:
        # No search needed
        yield f"data: {json.dumps({'type': 'thinking', 'content': 'No search needed.'})}\n\n"
        await asyncio.sleep(0.5)

        thinking_lines = [
            "Considering the context...",
            "Formulating response...",
        ]
        for line in thinking_lines:
            yield f"data: {json.dumps({'type': 'thinking', 'content': line})}\n\n"
            await asyncio.sleep(0.5)

        response_text = (
            f"[MOCK] Server received: '{request.prompt}'.\n\n"
            "**Tip:** To test the Web Search UI, try a prompt like:\n"
            "`search for latest ai news`"
        )

    # Stream the response content
    # Split by lines to preserve structure, then words
    lines = response_text.split("\n")
    for line in lines:
        words = line.split(" ")
        for word in words:
            yield f"data: {json.dumps({'type': 'content', 'content': word + ' '})}\n\n"
            await asyncio.sleep(0.02)  # Fast typing
        yield f"data: {json.dumps({'type': 'content', 'content': '\n'})}\n\n"

    yield f"data: {json.dumps({'type': 'done', 'metadata': {'prompt_tokens': 10, 'completion_tokens': len(response_text.split()), 'model': 'mock-model'}})}\n\n"


async def _stream_from_parallax(request: ChatRequest, request_id: str):
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
                    yield f"data: {json.dumps({'type': 'thinking', 'content': f'Found {len(search_results["results"])} results. Reading content...'})}\n\n"

                    # Format results for context
                    search_context = "\n\n[WEB SEARCH RESULTS]\n"
                    for i, res in enumerate(search_results["results"]):
                        search_context += (
                            f"Source {i + 1}: {res['title']} ({res['url']})\n"
                        )
                        if res.get("is_full_content"):
                            search_context += (
                                f"Content: {res.get('content', '')[:1000]}...\n"
                            )
                        else:
                            search_context += f"Snippet: {res['snippet']}\n"
                        search_context += "---\n"
                    search_context += "[END WEB SEARCH RESULTS]\n\n"
                else:
                    yield f"data: {json.dumps({'type': 'thinking', 'content': 'No relevant results found.'})}\n\n"
            else:
                yield f"data: {json.dumps({'type': 'thinking', 'content': 'No search needed.'})}\n\n"

        except Exception as e:
            logger.error(f"❌ [{request_id}] Smart search failed: {e}")
            yield f"data: {json.dumps({'type': 'thinking', 'content': f'Search failed: {e}'})}\n\n"

    try:
        # Inject search context
        modified_request = request.copy()
        if search_context:
            if modified_request.system_prompt:
                modified_request.system_prompt += search_context
            else:
                modified_request.system_prompt = (
                    "You are a helpful AI assistant.\n" + search_context
                )

        messages = _build_messages(modified_request)
        payload = _build_payload(modified_request, messages, stream=True)

        log_debug("Streaming payload prepared", request_id, {"payload": payload})

        async with httpx.AsyncClient() as client:
            async with client.stream(
                "POST", PARALLAX_SERVICE_URL, json=payload, timeout=None
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
