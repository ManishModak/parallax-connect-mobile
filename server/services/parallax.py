"""Parallax service client for API communication."""

import json
import time
from typing import Optional, Dict, Any

from ..logging_setup import get_logger
from ..config import DEBUG_MODE, TIMEOUT_FAST, MODEL_CACHE_TTL
from .http_client import get_async_http_client

logger = get_logger(__name__)


class ModelCache:
    """Simple TTL-based cache for model data."""

    def __init__(self, ttl_seconds: int = MODEL_CACHE_TTL):
        self._cache: Optional[Dict[str, Any]] = None
        self._cached_at: Optional[float] = None
        self._ttl = ttl_seconds
        logger.info(f"🗃️ Model cache initialized with {ttl_seconds}s TTL")

    def get(self) -> Optional[Dict[str, Any]]:
        """Get cached data if still valid."""
        if self._cache is None:
            if DEBUG_MODE:
                logger.debug("Cache miss: No cached data")
            return None

        age = time.time() - self._cached_at
        if age > self._ttl:
            if DEBUG_MODE:
                logger.debug(
                    f"Cache miss: Data expired (age: {age:.1f}s, TTL: {self._ttl}s)"
                )
            return None

        if DEBUG_MODE:
            logger.debug(
                f"✅ Cache hit: Data age {age:.1f}s (TTL: {self._ttl}s)",
                extra={"extra_data": {"age_seconds": age, "ttl_seconds": self._ttl}},
            )
        return self._cache

    def set(self, data: Dict[str, Any]) -> None:
        """Store data in cache."""
        self._cache = data
        self._cached_at = time.time()
        if DEBUG_MODE:
            logger.debug(
                "Cache updated",
                extra={
                    "extra_data": {
                        "model_count": len(data.get("models", [])),
                        "active_model": data.get("active"),
                    }
                },
            )

    def invalidate(self) -> None:
        """Manually invalidate cache."""
        self._cache = None
        self._cached_at = None
        logger.info("🗑️ Model cache invalidated")


class ParallaxClient:
    """Client for communicating with Parallax service."""

    def __init__(self, base_url: str = "http://localhost:3001"):
        self.base_url = base_url
        self.chat_url = f"{base_url}/v1/chat/completions"
        self._model_cache = ModelCache()
        logger.info(f"🔌 Parallax Client initialized at {base_url}")

    async def check_connection(self) -> bool:
        """Test connection to Parallax service."""
        try:
            client = await get_async_http_client()
            resp = await client.get(f"{self.base_url}/model/list", timeout=TIMEOUT_FAST)
            return resp.status_code == 200
        except Exception:
            return False

    async def get_models(self) -> Dict[str, Any]:
        """Fetch available models from Parallax."""
        # Check cache first
        cached_data = self._model_cache.get()
        if cached_data is not None:
            logger.info("📦 Returning cached model data")
            return cached_data

        active_model = None
        models = []

        start_time = time.time()

        if DEBUG_MODE:
            logger.debug("Fetching models from Parallax service")

        try:
            client = await get_async_http_client()
            # Get supported models list
            resp = await client.get(f"{self.base_url}/model/list", timeout=TIMEOUT_FAST)
            if resp.status_code == 200:
                response_data = resp.json()

                if DEBUG_MODE:
                    logger.debug(
                        "Received model list response",
                        extra={
                            "extra_data": {
                                "raw_response_keys": list(response_data.keys())
                                if isinstance(response_data, dict)
                                else "list"
                            }
                        },
                    )

                raw_models = response_data.get("data", [])
                if not raw_models and isinstance(response_data, list):
                    raw_models = response_data
                if raw_models and "id" in raw_models[0] and "name" not in raw_models[0]:
                    raw_models = [{"name": m.get("id"), **m} for m in raw_models]
                    if DEBUG_MODE:
                        logger.debug("Transformed model IDs to names")

                models = [
                    {
                        "id": m.get("name", "unknown"),
                        "name": m.get("name", "Unknown Model"),
                        "context_length": 32768,
                        "vram_gb": m.get("vram_gb", 0),
                    }
                    for m in raw_models
                ]

                if DEBUG_MODE:
                    logger.debug(
                        f"Parsed {len(models)} models",
                        extra={
                            "extra_data": {"model_names": [m["name"] for m in models]}
                        },
                    )

                # Get active model from cluster status
                if DEBUG_MODE:
                    logger.debug("Fetching active model from cluster status")

                try:
                    async with client.stream(
                        "GET", f"{self.base_url}/cluster/status", timeout=TIMEOUT_FAST
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
                                        if DEBUG_MODE:
                                            logger.debug(
                                                f"Found active model: {active_model}"
                                            )
                                        break
                                except json.JSONDecodeError:
                                    continue
                except Exception as e:
                    if DEBUG_MODE:
                        logger.debug(
                            f"Could not get cluster status: {e}",
                            extra={"extra_data": {"error": str(e)}},
                        )

        except Exception as e:
            logger.error(f"❌ Failed to fetch models: {e}")
            if DEBUG_MODE:
                logger.debug("Model fetch exception details", exc_info=True)

        default_model = active_model or (models[0]["id"] if models else "default")

        result = {
            "models": models,
            "active": active_model,
            "default": default_model,
        }

        # Cache the result
        self._model_cache.set(result)

        if DEBUG_MODE:
            logger.debug(
                f"Fetched models in {time.time() - start_time:.3f}s",
                extra={
                    "extra_data": {
                        "count": len(models),
                        "active_model": active_model,
                        "default_model": default_model,
                    }
                },
            )

        return result

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
            client = await get_async_http_client()
            resp = await client.get(f"{self.base_url}/model/list", timeout=TIMEOUT_FAST)
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
