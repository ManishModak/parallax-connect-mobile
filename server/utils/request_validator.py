"""
Request validation utilities for API endpoints.
"""

from fastapi import HTTPException
from typing import List, Dict, Any

from ..config import MAX_PROMPT_LENGTH, MAX_SYSTEM_PROMPT_LENGTH, MAX_MESSAGE_HISTORY
from ..logging_setup import get_logger

logger = get_logger(__name__)


def validate_chat_request(
    prompt: str,
    system_prompt: str = None,
    messages: List[Dict[str, Any]] = None,
    request_id: str = "unknown",
) -> None:
    """
    Validate chat request parameters.
    Raises HTTPException if validation fails.
    """
    # Validate prompt length
    if len(prompt) > MAX_PROMPT_LENGTH:
        logger.warning(
            f"⚠️ [{request_id}] Prompt exceeds max length",
            extra={
                "request_id": request_id,
                "extra_data": {
                    "prompt_length": len(prompt),
                    "max_allowed": MAX_PROMPT_LENGTH,
                },
            },
        )
        raise HTTPException(
            status_code=400,
            detail=f"Prompt too long. Maximum {MAX_PROMPT_LENGTH} characters allowed.",
        )

    # Validate system prompt length
    if system_prompt and len(system_prompt) > MAX_SYSTEM_PROMPT_LENGTH:
        logger.warning(
            f"⚠️ [{request_id}] System prompt exceeds max length",
            extra={
                "request_id": request_id,
                "extra_data": {
                    "system_prompt_length": len(system_prompt),
                    "max_allowed": MAX_SYSTEM_PROMPT_LENGTH,
                },
            },
        )
        raise HTTPException(
            status_code=400,
            detail=f"System prompt too long. Maximum {MAX_SYSTEM_PROMPT_LENGTH} characters allowed.",
        )

    # Validate message history count
    if messages and len(messages) > MAX_MESSAGE_HISTORY:
        logger.warning(
            f"⚠️ [{request_id}] Message history exceeds max count",
            extra={
                "request_id": request_id,
                "extra_data": {
                    "message_count": len(messages),
                    "max_allowed": MAX_MESSAGE_HISTORY,
                },
            },
        )
        raise HTTPException(
            status_code=400,
            detail=f"Too many messages. Maximum {MAX_MESSAGE_HISTORY} messages allowed.",
        )

    # Validate individual message lengths
    if messages:
        for i, msg in enumerate(messages):
            content = msg.get("content", "")
            if len(content) > MAX_PROMPT_LENGTH:
                logger.warning(
                    f"⚠️ [{request_id}] Message #{i} exceeds max length",
                    extra={
                        "request_id": request_id,
                        "extra_data": {
                            "message_index": i,
                            "message_length": len(content),
                            "max_allowed": MAX_PROMPT_LENGTH,
                        },
                    },
                )
                raise HTTPException(
                    status_code=400,
                    detail=f"Message #{i} too long. Maximum {MAX_PROMPT_LENGTH} characters per message.",
                )

    logger.debug(
        f"✅ [{request_id}] Request validation passed",
        extra={
            "request_id": request_id,
            "extra_data": {
                "prompt_length": len(prompt),
                "system_prompt_length": len(system_prompt) if system_prompt else 0,
                "message_count": len(messages) if messages else 0,
            },
        },
    )
