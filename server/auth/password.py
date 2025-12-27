"""Password authentication for server endpoints."""

import getpass
import secrets
import time
from collections import defaultdict, deque
from typing import Optional
from fastapi import Header, HTTPException, Request

from ..config import (
    get_password,
    set_password,
    REQUIRE_PASSWORD,
    SERVER_MODE,
    DEBUG_MODE,
)


class RateLimiter:
    """Simple in-memory rate limiter to block brute-force attempts."""

    def __init__(self, max_attempts: int = 5, window_seconds: int = 60):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self.attempts = defaultdict(deque)

    def is_blocked(self, ip: str) -> bool:
        """Check if an IP is blocked."""
        now = time.time()
        # Clean up old attempts for this IP
        while self.attempts[ip] and self.attempts[ip][0] < now - self.window_seconds:
            self.attempts[ip].popleft()

        return len(self.attempts[ip]) >= self.max_attempts

    def record_failure(self, ip: str):
        """Record a failed attempt for an IP."""
        now = time.time()
        self.attempts[ip].append(now)


# Global rate limiter instance
_rate_limiter = RateLimiter(max_attempts=5, window_seconds=60)


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


async def check_password(
    request: Request, x_password: Optional[str] = Header(default=None)
):
    """FastAPI dependency to verify password header with rate limiting."""
    # Always allow MOCK mode
    if SERVER_MODE == "MOCK":
        return True

    pwd = get_password()

    # If a password is configured, enforce it regardless of REQUIRE_PASSWORD/DEBUG
    if pwd:
        client_ip = request.client.host if request.client else "unknown"

        # Check rate limit before verifying password
        if _rate_limiter.is_blocked(client_ip):
            raise HTTPException(
                status_code=429,
                detail="Too many failed attempts. Please try again later.",
            )

        if x_password is None or not secrets.compare_digest(x_password, pwd):
            _rate_limiter.record_failure(client_ip)
            raise HTTPException(status_code=401, detail="Invalid password")
        return True

    # No password configured: optionally require based on REQUIRE_PASSWORD
    if REQUIRE_PASSWORD:
        raise HTTPException(
            status_code=401,
            detail="Password required. Set SERVER_PASSWORD env and provide X-Password header.",
        )

    # Passwordless and not required: allow (dev convenience)
    return True
