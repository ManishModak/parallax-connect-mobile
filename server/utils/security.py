"""Security utilities."""

import socket
import ipaddress
from typing import Optional
from urllib.parse import urlparse
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

def resolve_safe_url(url: str) -> Optional[str]:
    """
    Validate that a URL resolves to a public IP address and return that IP.
    Returns the first safe IP string found, or None if none are safe.

    This is intended for 'IP Pinning': the caller MUST connect to the
    returned IP address to prevent DNS rebinding attacks.
    """
    try:
        parsed = urlparse(url)
        hostname = parsed.hostname
        if not hostname:
            return None

        try:
            addr_info = socket.getaddrinfo(hostname, None)
        except socket.gaierror:
            logger.warning(f"⚠️ DNS resolution failed for {hostname}")
            return None

        # Iterate through resolved IPs and find the first safe one
        for family, _, _, _, sockaddr in addr_info:
            ip_str = str(sockaddr[0])
            if is_ip_allowed(ip_str):
                return ip_str

        logger.warning(f"⚠️ Blocked access - no safe IP found for {url}")
        return None

    except Exception as e:
        logger.error(f"❌ URL resolution error: {e}")
        return None

def validate_url(url: str) -> bool:
    """
    Strictly validate that ALL resolved IPs for a URL are public.
    Returns True if safe, False otherwise.

    WARNING: This check is vulnerable to DNS rebinding (TOCTOU) if the
    caller subsequently resolves the domain again.
    Use `resolve_safe_url` and connect to the IP directly for robust protection.
    """
    try:
        parsed = urlparse(url)
        hostname = parsed.hostname
        if not hostname:
            return False

        try:
            addr_info = socket.getaddrinfo(hostname, None)
        except socket.gaierror:
            logger.warning(f"⚠️ DNS resolution failed for {hostname}")
            return False

        # STRICT Check: If ANY IP is private, reject the whole URL.
        # This prevents attackers from using a domain that round-robins
        # between public and private IPs to bypass checks.
        for family, _, _, _, sockaddr in addr_info:
            ip_str = str(sockaddr[0])
            if not is_ip_allowed(ip_str):
                logger.warning(f"⚠️ Blocked access to internal IP {ip_str} for {url}")
                return False

        return True

    except Exception as e:
        logger.error(f"❌ URL validation error: {e}")
        return False
