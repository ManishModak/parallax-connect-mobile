"""Security utilities."""

import socket
import ipaddress
import urllib.parse
from urllib.parse import urlparse
from fastapi import HTTPException
from ..logging_setup import get_logger

logger = get_logger(__name__)

def is_ip_allowed(ip_str: str) -> bool:
    """
    Check if an IP address is allowed (public).
    Blocks private, loopback, link-local, and multicast addresses.
    """
    try:
        ip = ipaddress.ip_address(ip_str)
        if (
            ip.is_private
            or ip.is_loopback
            or ip.is_link_local
            or ip.is_multicast
            or ip.is_reserved
        ):
            return False
        return True
    except ValueError:
        return False

def validate_url(url: str) -> bool:
    """
    Validate that a URL resolves to a public IP address.
    Returns True if safe, False otherwise.
    """
    try:
        parsed = urlparse(url)
        hostname = parsed.hostname
        if not hostname:
            return False

        # Resolve hostname to IP
        # We use getaddrinfo to support both IPv4 and IPv6
        try:
            addr_info = socket.getaddrinfo(hostname, None)
        except socket.gaierror:
            logger.warning(f"⚠️ DNS resolution failed for {hostname}")
            return False

        for family, _, _, _, sockaddr in addr_info:
            ip_str = str(sockaddr[0])
            if not is_ip_allowed(ip_str):
                logger.warning(f"⚠️ Blocked access to internal IP {ip_str} for {url}")
                return False

        return True

    except Exception as e:
        logger.error(f"❌ URL validation error: {e}")
        return False

def validate_proxy_path(path: str) -> str:
    """
    Validates a path parameter to prevent path traversal attacks.
    Handles multiple layers of URL encoding.
    """
    decoded = path
    # Decode recursively to find hidden traversal attempts
    for _ in range(5):
        try:
            prev = decoded
            decoded = urllib.parse.unquote(decoded)
            if decoded == prev:
                break
        except Exception:
            break

    if ".." in decoded or "\\" in decoded:
        logger.warning(f"⚠️ Blocked potential path traversal in UI proxy: {path} (decoded: {decoded})")
        raise HTTPException(status_code=400, detail="Invalid path")

    if path.startswith("/") or decoded.startswith("/"):
        logger.warning(f"⚠️ Blocked absolute path in UI proxy: {path}")
        raise HTTPException(status_code=400, detail="Invalid path")

    return path
