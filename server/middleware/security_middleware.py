"""Middleware for adding security headers to responses."""

from starlette.middleware.base import BaseHTTPMiddleware
from fastapi import Request, Response
from typing import Callable

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Middleware that adds security-related headers to all responses."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        response = await call_next(request)

        # Prevent MIME sniffing
        response.headers["X-Content-Type-Options"] = "nosniff"

        # Protect against clickjacking (allow from same origin for UI proxy)
        response.headers["X-Frame-Options"] = "SAMEORIGIN"

        # Enable XSS protection filter in browsers that support it
        response.headers["X-XSS-Protection"] = "1; mode=block"

        # Control referrer information
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

        # HSTS (HTTP Strict Transport Security) - 1 year
        # Useful if the server is exposed via HTTPS, ignored on HTTP
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

        return response
