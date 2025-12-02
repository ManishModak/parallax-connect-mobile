"""Health and status endpoints."""

import time
from datetime import datetime
from fastapi import APIRouter, Depends, Request

from ..auth import check_password
from ..config import SERVER_MODE
from ..services.service_manager import service_manager
from ..logging_setup import get_logger
from ..utils.error_handler import log_debug

router = APIRouter()
logger = get_logger(__name__)


@router.get("/")
async def home(request: Request, _: bool = Depends(check_password)):
    """Root endpoint."""
    request_id = getattr(request.state, "request_id", "unknown")
    logger.info(
        "📍 Root endpoint accessed",
        extra={
            "request_id": request_id,
            "extra_data": {"mode": SERVER_MODE, "device": "Server Node"},
        },
    )
    return {"status": "online", "mode": SERVER_MODE, "device": "Server Node"}


@router.get("/healthz")
async def health_check():
    """Public health check (no password required)."""
    return {"status": "ok"}


@router.get("/status")
async def status_endpoint(request: Request, _: bool = Depends(check_password)):
    """Check server and Parallax connectivity status."""
    request_id = getattr(request.state, "request_id", "unknown")
    start_time = time.time()

    status = {
        "server": "online",
        "mode": SERVER_MODE,
        "timestamp": datetime.now().isoformat(),
    }

    if SERVER_MODE == "PROXY":
        parallax = service_manager.get_parallax_client()
        connected = await parallax.check_connection()

        if connected:
            status["parallax"] = "connected"
            log_debug("Parallax connection check passed", request_id)
        else:
            status["parallax"] = "disconnected"
            logger.warning(
                "⚠️ Parallax status check: disconnected",
                extra={
                    "request_id": request_id,
                    "extra_data": {"parallax_status": "disconnected"},
                },
            )

    elapsed = time.time() - start_time
    log_debug("Status check completed", request_id, {"duration": elapsed})

    return status
