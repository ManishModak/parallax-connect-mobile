"""Password authentication for server endpoints."""

import getpass
import secrets
import time
import asyncio
from typing import Optional, Dict, Tuple
from fastapi import Header, HTTPException, Request

from ..config import (
    get_password,
    set_password,
    REQUIRE_PASSWORD,
    SERVER_MODE,
    DEBUG_MODE,
)
from ..logging_setup import get_logger

logger = get_logger(__name__)


class RateLimiter:
    """
    Simple in-memory rate limiter to prevent brute-force attacks.
    Tracks failed attempts by IP address.
    """

    def __init__(self, max_attempts: int = 5, block_duration: int = 300):
        self.max_attempts = max_attempts
        self.block_duration = block_duration  # seconds
        self.failed_attempts: Dict[str, Tuple[int, float]] = {}  # ip -> (count, first_fail_time)
        self.blocked_ips: Dict[str, float] = {}  # ip -> unblock_time
        self._access_counter = 0

    def is_blocked(self, ip: str) -> bool:
        """Check if IP is currently blocked."""
        # Probabilistic cleanup (every 100 checks)
        self._access_counter += 1
        if self._access_counter > 100:
            self.cleanup()
            self._access_counter = 0

        if ip in self.blocked_ips:
            if time.time() < self.blocked_ips[ip]:
                return True
            else:
                del self.blocked_ips[ip]  # Unblock if time passed
                if ip in self.failed_attempts:
                    del self.failed_attempts[ip] # Reset counter
        return False

    def record_failure(self, ip: str):
        """Record a failed attempt for an IP."""
        now = time.time()

        # Check if already blocked (should have been checked by is_blocked)
        if self.is_blocked(ip):
            return

        count, first_time = self.failed_attempts.get(ip, (0, now))

        # Reset counter if it's been a while (e.g., 1 hour) since first failure
        if now - first_time > 3600:
            count = 0
            first_time = now

        count += 1
        self.failed_attempts[ip] = (count, first_time)

        if count >= self.max_attempts:
            self.block_ip(ip)

    def block_ip(self, ip: str):
        """Block an IP address."""
        self.blocked_ips[ip] = time.time() + self.block_duration
        logger.warning(f"🚫 IP {ip} blocked for {self.block_duration}s due to too many failed auth attempts.")

    def reset(self, ip: str):
        """Reset attempts for an IP (e.g. on successful login)."""
        if ip in self.failed_attempts:
            del self.failed_attempts[ip]
        if ip in self.blocked_ips:
            del self.blocked_ips[ip]

    def cleanup(self):
        """Remove old entries to prevent memory leaks."""
        now = time.time()
        # Remove expired blocks
        self.blocked_ips = {
            ip: t for ip, t in self.blocked_ips.items() if t > now
        }
        # Remove old failed attempts (older than 1 hour)
        self.failed_attempts = {
            ip: (c, t) for ip, (c, t) in self.failed_attempts.items() if now - t < 3600
        }


# Global rate limiter instance
_rate_limiter = RateLimiter()


def setup_password():
    """Prompt user for optional password protection with confirmation."""
    # Skip auth entirely in MOCK or DEBUG/dev scenarios
    if SERVER_MODE == "MOCK" or DEBUG_MODE:
        set_password(None)
        print("ℹ️  Auth disabled (mock/dev mode).")
        return

    # Check if password was already configured via env vars (e.g. by launcher)
    current_pwd = get_password()
    if current_pwd is not None:
        if current_pwd:
            print(
                f"✅ Password configured from environment (Length: {len(current_pwd)})"
            )
        else:
            print("⚠️  No password set (configured via launcher). Server is open.")
        return

    # If password is required, fail closed rather than prompting in non-interactive envs
    if REQUIRE_PASSWORD:
        raise RuntimeError(
            "SERVER_PASSWORD is required. Set the env var SERVER_PASSWORD "
            "or disable REQUIRE_PASSWORD (dev only)."
        )

    try:
        choice = input("\n🔒 Set a password for this server? (y/n): ").strip().lower()
    except EOFError:
        choice = "n"

    if choice == "y":
        password = getpass.getpass("Enter password: ").strip()
        if not password:
            set_password(None)
            print("⚠️  Empty password. Server remains open.\n")
            return

        confirm_password = getpass.getpass("Retype password: ").strip()

        if password != confirm_password:
            print("❌ Passwords do not match. Server remains open.\n")
            set_password(None)
            return

        set_password(password)
        print("✅ Password protection enabled\n")
    else:
        set_password(None)
        print("⚠️  No password set. Server is open.\n")

def get_client_ip(request: Request) -> str:
    """
    Get the client IP address, respecting X-Forwarded-For if present.
    Essential for rate limiting behind reverse proxies.
    """
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        # X-Forwarded-For: client, proxy1, proxy2...
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"

async def check_password(
    request: Request, x_password: Optional[str] = Header(default=None)
):
    """FastAPI dependency to verify password header."""
    # Always allow MOCK mode
    if SERVER_MODE == "MOCK":
        return True

    client_ip = get_client_ip(request)

    # Check rate limit before anything else
    if _rate_limiter.is_blocked(client_ip):
        raise HTTPException(
            status_code=429,
            detail="Too many failed attempts. Please try again later.",
        )

    pwd = get_password()

    # If a password is configured, enforce it regardless of REQUIRE_PASSWORD/DEBUG
    if pwd:
        if x_password is None or not secrets.compare_digest(x_password, pwd):
            _rate_limiter.record_failure(client_ip)
            # Add delay to mitigate timing attacks (though compare_digest helps)
            await asyncio.sleep(0.1)
            raise HTTPException(status_code=401, detail="Invalid password")

        # Reset failure count on success
        _rate_limiter.reset(client_ip)
        return True

    # No password configured: optionally require based on REQUIRE_PASSWORD
    if REQUIRE_PASSWORD:
        raise HTTPException(
            status_code=401,
            detail="Password required. Set SERVER_PASSWORD env and provide X-Password header.",
        )

    # Passwordless and not required: allow (dev convenience)
    return True
