"""
Centralized Error Handling Utilities.
Standardizes error logging and HTTP exception generation.
"""

from fastapi import HTTPException
from typing import Optional, Dict, Any
import traceback

from ..logging_setup import get_logger
from ..config import DEBUG_MODE

logger = get_logger(__name__)


def handle_service_error(
    e: Exception,
    service_name: str,
    request_id: str,
    status_code: int = 500,
    detail: Optional[str] = None,
) -> HTTPException:
    """
    Log error with full context and return appropriate HTTPException.
    """
    error_msg = str(e)

    # Security: Don't leak internal exception details in production
    if detail:
        user_detail = detail
    elif DEBUG_MODE:
        user_detail = f"{service_name} Error: {error_msg}"
    else:
        user_detail = f"{service_name} Error: An unexpected error occurred."

    # Log structure
    log_data = {
        "request_id": request_id,
        "extra_data": {
            "service": service_name,
            "error_type": type(e).__name__,
            "error_message": error_msg,
        },
    }

    # Add stack trace in debug mode
    if DEBUG_MODE:
        log_data["extra_data"]["stack_trace"] = traceback.format_exc()

    logger.error(
        f"❌ [{request_id}] {service_name} failed: {error_msg}", extra=log_data
    )

    return HTTPException(status_code=status_code, detail=user_detail)


def log_warning(message: str, request_id: str, data: Optional[Dict[str, Any]] = None):
    """Log a warning with standardized context."""
    extra = {"request_id": request_id, "extra_data": data or {}}
    logger.warning(f"⚠️ [{request_id}] {message}", extra=extra)


def log_debug(message: str, request_id: str, data: Optional[Dict[str, Any]] = None):
    """Log debug info only if DEBUG_MODE is enabled."""
    if not DEBUG_MODE:
        return

    extra = {"request_id": request_id, "extra_data": data or {}}
    logger.debug(f"🐛 [{request_id}] {message}", extra=extra)
