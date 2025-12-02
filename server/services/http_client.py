"""Shared HTTP client utilities.

Provides a single AsyncClient instance with connection pooling so that
all services reuse TCP connections instead of creating a new client
for every request.
"""

from typing import Optional

import httpx

from ..config import TIMEOUT_DEFAULT, TIMEOUT_FAST
from ..logging_setup import get_logger

logger = get_logger(__name__)

_async_client: Optional[httpx.AsyncClient] = None
_scraping_client: Optional[httpx.AsyncClient] = None


def _create_async_client() -> httpx.AsyncClient:
    """Strict client for internal API calls (Parallax)."""
    timeout = httpx.Timeout(TIMEOUT_DEFAULT, connect=TIMEOUT_FAST)
    client = httpx.AsyncClient(
        timeout=timeout,
        follow_redirects=True,
        verify=True,  # Explicitly enforce certificate verification
    )
    logger.info("🌐 Shared Async HTTP client created")
    return client


def _create_scraping_client() -> httpx.AsyncClient:
    """Client for external web scraping with tuned timeouts."""
    timeout = httpx.Timeout(TIMEOUT_FAST, connect=5.0)
    client = httpx.AsyncClient(
        timeout=timeout,
        follow_redirects=True,
        verify=True,  # Keep verification on; failures are handled in scrape code
    )
    logger.info("🌐 Shared scraping HTTP client created")
    return client


async def get_async_http_client() -> httpx.AsyncClient:
    """Get the shared AsyncClient instance for internal APIs."""
    global _async_client

    if _async_client is None:
        _async_client = _create_async_client()
    return _async_client


async def get_scraping_http_client() -> httpx.AsyncClient:
    """Get the shared AsyncClient instance for scraping."""
    global _scraping_client

    if _scraping_client is None:
        _scraping_client = _create_scraping_client()
    return _scraping_client


async def close_async_http_client() -> None:
    """Close any shared AsyncClient instances if they exist."""
    global _async_client, _scraping_client

    if _async_client is not None:
        await _async_client.aclose()
        _async_client = None
        logger.info("🛑 Shared Async HTTP client closed")

    if _scraping_client is not None:
        await _scraping_client.aclose()
        _scraping_client = None
        logger.info("🛑 Shared scraping HTTP client closed")


