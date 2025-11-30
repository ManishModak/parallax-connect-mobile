"""Model and info endpoints."""

from datetime import datetime
from fastapi import APIRouter, Depends

from ..auth import check_password
from ..config import SERVER_MODE
from ..services import ParallaxClient
from ..logging_setup import get_logger

router = APIRouter()
logger = get_logger(__name__)
parallax = ParallaxClient()


@router.get("/models")
async def models_endpoint(_: bool = Depends(check_password)):
    """Returns available and active models from Parallax."""
    if SERVER_MODE == "MOCK":
        return {
            "models": [
                {
                    "id": "mock-model",
                    "name": "Mock Model",
                    "context_length": 4096,
                    "vram_gb": 8,
                }
            ],
            "active": "mock-model",
            "default": "mock-model",
        }

    result = await parallax.get_models()
    logger.info(
        f"📋 Models: {len(result['models'])} available",
        extra={
            "extra_data": {
                "count": len(result["models"]),
                "active": result["active"] or "none",
                "models": [m["id"] for m in result["models"]],
            }
        },
    )
    return result


@router.get("/info")
async def info_endpoint(_: bool = Depends(check_password)):
    """Returns server capabilities for dynamic feature configuration."""
    info = {
        "server_version": "1.0.0",
        "mode": SERVER_MODE,
        "capabilities": {
            "vram_gb": 0,
            "vision_supported": False,
            "document_processing": False,
            "max_context_window": 4096,
            "multimodal_supported": False,
        },
        "timestamp": datetime.now().isoformat(),
    }

    if SERVER_MODE == "MOCK":
        info["capabilities"] = {
            "vram_gb": 8,
            "vision_supported": False,
            "document_processing": False,
            "max_context_window": 4096,
            "multimodal_supported": False,
        }
        return info

    result = await parallax.get_capabilities()
    info["capabilities"] = result["capabilities"]
    info["active_models"] = result["active_models"]
    logger.info(
        f"📊 Server capabilities",
        extra={
            "extra_data": {
                "capabilities": info["capabilities"],
                "active_models": result["active_models"],
            }
        },
    )

    return info
