"""OpenAI compatibility endpoints."""

import time
from datetime import datetime
from fastapi import APIRouter, Depends, Request, HTTPException

from ...auth import check_password
from ...config import SERVER_MODE, PARALLAX_SERVICE_URL, DEBUG_MODE, TIMEOUT_DEFAULT
from ...models import ChatRequest
from ...logging_setup import get_logger
from ...services.http_client import get_async_http_client
from ...utils.error_handler import handle_service_error
from .mock_handlers import handle_mock_chat

router = APIRouter()
logger = get_logger(__name__)


@router.post("/v1/chat/completions")
async def openai_chat_completion(
    request: Request, chat_request: ChatRequest, _: bool = Depends(check_password)
):
    """
    OpenAI-compatible chat completion endpoint.
    Used by mobile app for intent classification and other auxiliary tasks.
    """
    request_id = getattr(
        request.state, "request_id", datetime.now().strftime("%Y%m%d%H%M%S%f")
    )

    logger.info(
        f"🤖 [{request_id}] OpenAI Compat Request: {chat_request.model}",
        extra={
            "request_id": request_id,
            "extra_data": {
                "model": chat_request.model,
                "stream": False,
                "mode": SERVER_MODE,
            },
        },
    )

    # In MOCK mode, return a mock OpenAI-format response for intent classification
    if SERVER_MODE == "MOCK":
        # Extract user query from messages if prompt not set
        user_query = chat_request.prompt or ""
        if not user_query and chat_request.messages:
            for msg in reversed(chat_request.messages):
                if msg.get("role") == "user":
                    user_query = msg.get("content", "")
                    break

        # Simple heuristic for mock intent classification
        lower_query = user_query.lower()
        needs_search = any(
            trigger in lower_query
            for trigger in [
                "price",
                "news",
                "latest",
                "current",
                "search",
                "today",
                "weather",
                "who is",
                "what is",
            ]
        )

        # Return OpenAI-compatible format
        mock_intent = {
            "needs_search": needs_search,
            "search_query": user_query if needs_search else "",
            "reason": "Mock heuristic match" if needs_search else "No triggers found",
        }

        import json

        return {
            "id": f"chatcmpl-mock-{request_id}",
            "object": "chat.completion",
            "model": "mock-model",
            "choices": [
                {
                    "index": 0,
                    "messages": {  # Note: Parallax uses 'messages' (plural) not 'message'
                        "role": "assistant",
                        "content": json.dumps(mock_intent),
                    },
                    "finish_reason": "stop",
                }
            ],
            "usage": {"prompt_tokens": 10, "completion_tokens": 20, "total_tokens": 30},
        }

    # In NORMAL/DEBUG/PROXY mode, forward to Parallax
    try:
        client = await get_async_http_client()

        # Prepare payload for Parallax
        payload = chat_request.model_dump(exclude_none=True)
        # Ensure stream is false for this endpoint as it expects a single response
        payload["stream"] = False

        resp = await client.post(
            PARALLAX_SERVICE_URL, json=payload, timeout=TIMEOUT_DEFAULT
        )

        if resp.status_code != 200:
            raise HTTPException(
                status_code=resp.status_code, detail=f"Parallax Error: {resp.text}"
            )

        return resp.json()

    except Exception as e:
        return handle_service_error(e, "OpenAI Compat Endpoint", request_id)
