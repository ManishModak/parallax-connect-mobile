"""Parallax service client for API communication."""

import json
import httpx
import time
from typing import Optional, List, Dict, Any

from ..logging_setup import get_logger
from ..config import DEBUG_MODE

logger = get_logger(__name__)


class ParallaxClient:
    """Client for communicating with Parallax service."""

    def __init__(self, base_url: str = "http://localhost:3001"):
        self.base_url = base_url
        self.chat_url = f"{base_url}/v1/chat/completions"
        logger.info(f"🔌 Parallax Client initialized at {base_url}")

    async def check_connection(self) -> bool:
        """Test connection to Parallax service."""
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(f"{self.base_url}/model/list", timeout=5.0)
                return resp.status_code == 200
        except Exception:
            return False

    async def get_models(self) -> Dict[str, Any]:
        """Fetch available models from Parallax."""
        active_model = None
        models = []

        start_time = time.time()

        try:
            async with httpx.AsyncClient() as client:
                # Get supported models list
                resp = await client.get(f"{self.base_url}/model/list", timeout=5.0)
                if resp.status_code == 200:
                    response_data = resp.json()
                    raw_models = response_data.get("data", [])
                    if not raw_models and isinstance(response_data, list):
                        raw_models = response_data
                    if (
                        raw_models
                        and "id" in raw_models[0]
                        and "name" not in raw_models[0]
                    ):
                        raw_models = [{"name": m.get("id"), **m} for m in raw_models]

                    models = [
                        {
                            "id": m.get("name", "unknown"),
                            "name": m.get("name", "Unknown Model"),
                            "context_length": 32768,
                            "vram_gb": m.get("vram_gb", 0),
                        }
                        for m in raw_models
                    ]

                # Get active model from cluster status
                try:
                    async with client.stream(
                        "GET", f"{self.base_url}/cluster/status", timeout=2.0
                    ) as stream:
                        async for line in stream.aiter_lines():
                            if line.strip():
                                line_data = (
                                    line[6:] if line.startswith("data: ") else line
                                )
                                if line_data == "[DONE]":
                                    break
                                try:
                                    status_data = json.loads(line_data)
                                    active_model = (
                                        status_data.get("data", {}).get("model_name")
                                        or status_data.get("model_name")
                                        or status_data.get("model")
                                    )
                                    if active_model:
                                        break
                                except json.JSONDecodeError:
                                    continue
                except Exception as e:
                    if DEBUG_MODE:
                        logger.debug(f"Could not get cluster status: {e}")

        except Exception as e:
            logger.error(f"❌ Failed to fetch models: {e}")

        default_model = active_model or (models[0]["id"] if models else "default")

        if DEBUG_MODE:
            logger.debug(
                f"Fetched models in {time.time() - start_time:.3f}s",
                extra={"extra_data": {"count": len(models)}},
            )

        return {
            "models": models,
            "active": active_model,
            "default": default_model,
        }

    async def get_capabilities(self) -> Dict[str, Any]:
        """Fetch server capabilities from Parallax."""
        capabilities = {
            "vram_gb": 0,
            "vision_supported": False,
            "document_processing": False,
            "max_context_window": 4096,
            "multimodal_supported": False,
        }
        active_models = []

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(f"{self.base_url}/model/list", timeout=5.0)
                if resp.status_code == 200:
                    model_data = resp.json()
                    models = model_data.get("data", [])
                    if not models and isinstance(model_data, list):
                        models = model_data
                    if models and isinstance(models[0], dict):
                        if "id" in models[0] and "name" not in models[0]:
                            models = [{"name": m.get("id"), **m} for m in models]

                    if models:
                        max_vram = max((m.get("vram_gb", 0) for m in models), default=0)
                        capabilities["vram_gb"] = max_vram if max_vram > 0 else 8
                        capabilities["document_processing"] = True
                        capabilities["max_context_window"] = 32768
                        active_models = [m.get("name", "unknown") for m in models[:5]]

        except Exception as e:
            logger.error(f"❌ Failed to fetch capabilities: {e}")

        return {"capabilities": capabilities, "active_models": active_models}
