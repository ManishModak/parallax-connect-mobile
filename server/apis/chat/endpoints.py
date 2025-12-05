"""Chat API endpoints."""

import re
import time
from datetime import datetime
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, Request
from fastapi.responses import StreamingResponse

from ...auth import check_password
from ...config import SERVER_MODE, PARALLAX_SERVICE_URL, DEBUG_MODE, TIMEOUT_DEFAULT
from ...models import ChatRequest
from ...logging_setup import get_logger
from ...services.http_client import get_async_http_client
from ...utils.error_handler import handle_service_error, log_debug
from ...utils.request_validator import validate_chat_request
from .helpers import (
    perform_smart_search,
    build_messages,
    build_payload,
    detect_document_content,
    build_document_system_prompt,
)
from .mock_handlers import handle_mock_chat, mock_stream
from .proxy_handlers import stream_from_parallax
from .openai_compat import router as openai_router

router = APIRouter()
router.include_router(openai_router)
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

    log_debug("Full chat request payload", request_id, chat_request.model_dump())

    validate_chat_request(
        prompt=chat_request.prompt,
        system_prompt=chat_request.system_prompt,
        messages=chat_request.messages,
        request_id=request_id,
    )

    if SERVER_MODE == "MOCK":
        return await handle_mock_chat(chat_request, request_id)

    # Detect document content submissions
    is_document, doc_content, user_query = detect_document_content(chat_request.prompt)

    modified_request = chat_request.model_copy()

    if is_document:
        # Document detected - inject appropriate system prompt
        logger.info(f"📄 [{request_id}] Document detected ({len(doc_content)} chars)")
        doc_system_prompt = build_document_system_prompt(doc_content, user_query)
        modified_request.system_prompt = doc_system_prompt
        # Set prompt to user query (or empty if no query)
        modified_request.prompt = (
            user_query if user_query else "Please analyze this document."
        )
        logger.info(f"📄 [{request_id}] User query: '{user_query or '(none)'}'")

    # Smart Search - only if not a document and web search enabled
    search_context = ""
    if not is_document and chat_request.web_search_enabled:
        search_context = await perform_smart_search(chat_request, request_id)

    # PROXY mode
    try:
        logger.info(
            f"🔄 [{request_id}] Forwarding to Parallax at {PARALLAX_SERVICE_URL}"
        )

        client = await get_async_http_client()
        if search_context:
            if modified_request.system_prompt:
                modified_request.system_prompt += search_context
            else:
                modified_request.system_prompt = (
                    "You are a helpful AI assistant.\n" + search_context
                )

        messages = build_messages(modified_request)
        payload = build_payload(modified_request, messages, stream=False)

        log_debug(
            "Proxy payload prepared", request_id, {"payload_keys": list(payload.keys())}
        )

        if DEBUG_MODE:
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

    log_debug("Full stream request payload", request_id, chat_request.model_dump())

    validate_chat_request(
        prompt=chat_request.prompt,
        system_prompt=chat_request.system_prompt,
        messages=chat_request.messages,
        request_id=request_id,
    )

    if SERVER_MODE == "MOCK":
        return StreamingResponse(
            mock_stream(chat_request), media_type="text/event-stream"
        )

    return StreamingResponse(
        stream_from_parallax(chat_request, request_id),
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
    """
    Vision endpoint with server-side OCR.

    Extracts text from images using EasyOCR and forwards to Parallax
    for LLM-based understanding and response.
    """
    from ...services.ocr_service import get_ocr_service
    from ...services.prompts import get_prompt
    from ...config import OCR_ENABLED

    request_id = datetime.now().strftime("%Y%m%d%H%M%S%f")
    logger.info(f"📸 [{request_id}] Vision request: {prompt[:50]}...")

    if SERVER_MODE == "MOCK":
        return {
            "response": f"[MOCK] Vision Analysis: I see a simulated image. Prompt: {prompt}"
        }

    # Get OCR service
    ocr_service = get_ocr_service()
    if ocr_service is None or not OCR_ENABLED:
        logger.warning(f"⚠️ [{request_id}] Server OCR is disabled")
        return {
            "response": "[Server OCR is disabled. Enable with OCR_ENABLED=true or use mobile Edge OCR.]",
            "ocr_enabled": False,
        }

    try:
        # Read image bytes
        image_bytes = await image.read()
        logger.info(f"📸 [{request_id}] Processing image ({len(image_bytes)} bytes)")

        # Extract text via OCR
        ocr_result = await ocr_service.analyze_image(image_bytes)
        extracted_text = ocr_result.get("text", "")
        confidence = ocr_result.get("confidence", 0.0)

        logger.info(
            f"🔤 [{request_id}] OCR extracted {len(extracted_text)} chars "
            f"(confidence: {confidence:.0%})"
        )

        if not extracted_text.strip():
            return {
                "response": "No text was detected in the image. The image may be too blurry, "
                "contain no text, or the text may be in an unsupported language.",
                "ocr_enabled": True,
                "extracted_text": "",
            }

        # Build context prompt for LLM - use appropriate prompt based on whether user asked a question
        user_has_query = bool(prompt and prompt.strip())

        if user_has_query:
            # User asked a specific question about the image
            context_prompt = get_prompt(
                "image_context",
                analysis=extracted_text,
                query=prompt,
            )
            user_message = prompt
        else:
            # No specific question - use analysis prompt
            context_prompt = get_prompt(
                "image_analysis",
                analysis=extracted_text,
            )
            user_message = "Please analyze this image."

        logger.info(
            f"📸 [{request_id}] Using {'image_context' if user_has_query else 'image_analysis'} prompt"
        )

        # Forward to Parallax for LLM response
        client = await get_async_http_client()
        payload = {
            "model": "default",
            "messages": [
                {"role": "system", "content": context_prompt},
                {
                    "role": "user",
                    "content": user_message,
                },
            ],
            "stream": False,
            "max_tokens": 2048,
            "temperature": 0.7,
        }

        resp = await client.post(
            PARALLAX_SERVICE_URL, json=payload, timeout=TIMEOUT_DEFAULT
        )

        if resp.status_code == 200:
            data = resp.json()
            choice = data["choices"][0]
            content = (
                choice.get("messages", {}).get("content")
                or choice.get("message", {}).get("content")
                or ""
            )

            return {
                "response": content,
                "ocr_enabled": True,
                "extracted_text": extracted_text,
                "confidence": confidence,
            }
        else:
            logger.error(f"❌ [{request_id}] Parallax returned {resp.status_code}")
            return {
                "response": f"Error from LLM service: {resp.text}",
                "ocr_enabled": True,
                "extracted_text": extracted_text,
            }

    except Exception as e:
        logger.error(f"❌ [{request_id}] Vision processing failed: {e}")
        return handle_service_error(e, "Vision Endpoint", request_id)
