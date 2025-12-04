"""Model and info endpoints."""

import time
from datetime import datetime
from fastapi import APIRouter, Depends, Request

from ..auth import check_password
from ..config import SERVER_MODE
from ..services.service_manager import service_manager
from ..logging_setup import get_logger
from ..utils.error_handler import handle_service_error, log_debug

router = APIRouter()
logger = get_logger(__name__)


@router.get("/models")
async def models_endpoint(request: Request, _: bool = Depends(check_password)):
    """Returns available and active models from Parallax."""
    request_id = getattr(request.state, "request_id", "unknown")

    if SERVER_MODE == "MOCK":
        return {
            "models": [
                {
                    "id": "qwen-32b",
                    "name": "Qwen 32B",
                    "context_length": 32768,
                    "vram_gb": 24,
                },
                {
                    "id": "llama-70b",
                    "name": "Llama 70B",
                    "context_length": 8192,
                    "vram_gb": 48,
                },
                {
                    "id": "mistral-7b",
                    "name": "Mistral 7B",
                    "context_length": 32768,
                    "vram_gb": 8,
                },
            ],
            "active": "qwen-32b",
            "default": "qwen-32b",
        }

    try:
        parallax = service_manager.get_parallax_client()
        start_time = time.time()

        result = await parallax.get_models()

        elapsed = time.time() - start_time

        logger.info(
            f"📋 Models: {len(result['models'])} available",
            extra={
                "request_id": request_id,
                "extra_data": {
                    "count": len(result["models"]),
                    "active": result["active"] or "none",
                    "models": [m["id"] for m in result["models"]],
                    "duration": elapsed,
                },
            },
        )
        return result

    except Exception as e:
        return handle_service_error(e, "Models Endpoint", request_id)


@router.get("/info")
async def info_endpoint(request: Request, _: bool = Depends(check_password)):
    """Returns server capabilities for dynamic feature configuration."""
    request_id = getattr(request.state, "request_id", "unknown")

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

    try:
        parallax = service_manager.get_parallax_client()
        result = await parallax.get_capabilities()

        info["capabilities"] = result["capabilities"]
        info["active_models"] = result["active_models"]

        log_debug("Capabilities fetched", request_id, info["capabilities"])

        return info

    except Exception as e:
        return handle_service_error(e, "Info Endpoint", request_id)
