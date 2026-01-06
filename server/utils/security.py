"""Security utilities."""

import socket
import ipaddress
from urllib.parse import urlparse, unquote
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
    Validate and decode a proxy path to prevent path traversal.
    Recursively decodes the path to handle double/triple encoding.
    Raises ValueError if path contains traversal attempts.
    """
    decoded = path
    # Recursively decode until stable or too many iterations
    for _ in range(5):
        new_decoded = unquote(decoded)
        if new_decoded == decoded:
            break
        decoded = new_decoded

    # Check for traversal indicators in the fully decoded string
    if ".." in decoded or decoded.startswith("/") or "\\" in decoded:
        raise ValueError("Invalid path: Path traversal detected")

    return decoded
