"""Parallax service client for API communication."""

import json
import time
from typing import Optional, Dict, Any

import httpx

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
                if raw_models and isinstance(raw_models[0], dict):
                    # Normalize keys; Parallax returns name + vram_gb
                    models = [
                        {
                            "id": m.get("name", m.get("id", "unknown")),
                            "name": m.get("name", m.get("id", "Unknown Model")),
                            "vram_gb": m.get("vram_gb", 0),
                        }
                        for m in raw_models
                    ]
                else:
                    models = []

                if DEBUG_MODE:
                    logger.debug(
                        f"Parsed {len(models)} models",
                        extra={
                            "extra_data": {"model_names": [m["name"] for m in models]}
                        },
                    )

                # Get active model from cluster status (long-lived stream; use relaxed timeout)
                if DEBUG_MODE:
                    logger.debug("Fetching active model from cluster status")

                try:
                    async with client.stream(
                        "GET",
                        f"{self.base_url}/cluster/status",
                        timeout=httpx.Timeout(None, connect=TIMEOUT_FAST),
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
            # Provide user-friendly error messages
            error_type = type(e).__name__
            if "ConnectError" in error_type or "connection" in str(e).lower():
                logger.warning(
                    f"⚠️ Parallax not reachable at {self.base_url} - is it running?"
                )
            else:
                logger.error(f"❌ Failed to fetch models: {e}")

            if DEBUG_MODE:
                # Show condensed error info in debug mode (not full stacktrace)
                import traceback

                tb_lines = traceback.format_exception(type(e), e, e.__traceback__)
                # Only show last 3 lines of traceback for brevity
                condensed = "".join(tb_lines[-3:]).strip()
                logger.debug(f"Error details: {condensed}")

        default_model = active_model or (models[0]["id"] if models else "default")

        result = {
            "models": models,
            "active": active_model,
            "default": default_model,
        }

        # Only cache if we actually got models - don't cache empty results from connection failures
        if models:
            self._model_cache.set(result)
        else:
            logger.info("📋 Not caching empty model list (Parallax may be starting up)")

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
                    active_models = [m.get("name", m.get("id", "unknown")) for m in models]
                    max_vram = max((m.get("vram_gb", 0) for m in models), default=0)
                    capabilities["vram_gb"] = max_vram if max_vram > 0 else 0
                    # Do not claim document support unless provided explicitly
                    capabilities["document_processing"] = False

                if not active_models:
                    active_models = []

        except Exception as e:
            # Provide user-friendly error messages
            error_type = type(e).__name__
            if "ConnectError" in error_type or "connection" in str(e).lower():
                logger.warning(
                    f"⚠️ Parallax not reachable at {self.base_url} - is it running?"
                )
            else:
                logger.error(f"❌ Failed to fetch capabilities: {e}")

            if DEBUG_MODE:
                import traceback

                tb_lines = traceback.format_exception(type(e), e, e.__traceback__)
                condensed = "".join(tb_lines[-3:]).strip()
                logger.debug(f"Error details: {condensed}")

        return {"capabilities": capabilities, "active_models": active_models}
