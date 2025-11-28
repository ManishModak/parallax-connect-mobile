"""Health and status endpoints."""

from datetime import datetime
from fastapi import APIRouter, Depends

from ..auth import check_password
from ..config import SERVER_MODE
from ..services import ParallaxClient
from ..logging_setup import get_logger

router = APIRouter()
logger = get_logger(__name__)
parallax = ParallaxClient()


@router.get("/")
async def home(_: bool = Depends(check_password)):
    """Root endpoint."""
    logger.info("📍 Root endpoint accessed")
    return {"status": "online", "mode": SERVER_MODE, "device": "Server Node"}


@router.get("/healthz")
async def health_check():
    """Public health check (no password required)."""
    return {"status": "ok"}


@router.get("/status")
async def status_endpoint(_: bool = Depends(check_password)):
    """Check server and Parallax connectivity status."""
    status = {
        "server": "online",
        "mode": SERVER_MODE,
        "timestamp": datetime.now().isoformat(),
    }

    if SERVER_MODE == "PROXY":
        connected = await parallax.check_connection()
        if connected:
            status["parallax"] = "connected"
            logger.info("✅ Parallax status check: connected")
        else:
            status["parallax"] = "disconnected"
            logger.warning("⚠️ Parallax status check: disconnected")

    return status
