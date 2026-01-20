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
    Validate a proxy path to prevent path traversal.
    Recursively decodes the path to detect hidden traversal attempts (e.g. %2e%2e).

    Returns the original path if safe.
    Raises ValueError if path is invalid/dangerous.
    """
    decoded = path
    # Limit recursion to prevent DoS
    for _ in range(5):
        try:
            prev = decoded
            decoded = unquote(decoded)

            # Check for null bytes which can terminate strings early in some systems
            if "\0" in decoded:
                raise ValueError("Null byte detected")

            # Check for path traversal markers
            if ".." in decoded or "\\" in decoded:
                raise ValueError("Path traversal detected")

            # If no change, we are done
            if prev == decoded:
                break
        except Exception as e:
            # If decoding fails or ValueError raised above
            raise ValueError(f"Invalid path encoding: {str(e)}")

    # Check if the final path attempts to be absolute or root-relative in a dangerous way
    # Note: We allow paths starting with / if they are just API routes, but typically
    # a proxy path param in FastAPI doesn't start with / unless passed that way.
    # We strictly block anything resolving to root or absolute path semantics if intended to be relative.
    if decoded.startswith("/"):
        # Depends on usage, but for "ui/{path:path}", path usually shouldn't start with /
        # If it does, it might be interpreted as absolute on the target system.
        raise ValueError("Path must be relative")

    return path
