"""Middleware for logging HTTP requests and responses."""

import time
import uuid
from typing import Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp

from ..logging_setup import get_logger

logger = get_logger(__name__)


class LogMiddleware(BaseHTTPMiddleware):
    """Middleware to log all requests and responses."""

    def __init__(self, app: ASGIApp):
        super().__init__(app)

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Process the request and log details."""
        request_id = str(uuid.uuid4())
        start_time = time.time()

        # Add request ID to state for access in endpoints
        request.state.request_id = request_id

        # Log Request
        client_host = request.client.host if request.client else "unknown"

        # Capture body for logging (if JSON and not too large)
        body_log = "<body_not_captured>"
        try:
            content_type = request.headers.get("content-type", "")
            if "application/json" in content_type:
                body_bytes = await request.body()

                # Re-inject body for downstream consumers
                async def receive():
                    return {"type": "http.request", "body": body_bytes}

                request._receive = receive

                if len(body_bytes) < 10000:  # Limit to 10KB
                    body_log = body_bytes.decode("utf-8")
                else:
                    body_log = f"<body_too_large_len_{len(body_bytes)}>"
        except Exception as e:
            body_log = f"<error_reading_body: {e}>"

        logger.info(
            f"➡️ [{request_id}] {request.method} {request.url.path}",
            extra={
                "request_id": request_id,
                "extra_data": {
                    "type": "request",
                    "method": request.method,
                    "path": request.url.path,
                    "query_params": str(request.query_params),
                    "client_ip": client_host,
                    "user_agent": request.headers.get("user-agent"),
                    "body": body_log,
                },
            },
        )

        try:
            response = await call_next(request)

            # Calculate duration
            duration = time.time() - start_time

            # Log Response
            logger.info(
                f"⬅️ [{request_id}] {response.status_code} ({duration:.3f}s)",
                extra={
                    "request_id": request_id,
                    "extra_data": {
                        "type": "response",
                        "status_code": response.status_code,
                        "duration_seconds": duration,
                    },
                },
            )

            # Add request ID to response headers
            response.headers["X-Request-ID"] = request_id

            return response

        except Exception as e:
            duration = time.time() - start_time
            logger.error(
                f"❌ [{request_id}] Request failed: {e}",
                exc_info=True,
                extra={
                    "request_id": request_id,
                    "extra_data": {
                        "type": "error",
                        "error": str(e),
                        "duration_seconds": duration,
                    },
                },
            )
            raise e
