"""Password authentication for server endpoints."""

import getpass
import secrets
import time
from typing import Optional, Dict, List
from fastapi import Header, HTTPException, Request

from ..config import (
    get_password,
    set_password,
    REQUIRE_PASSWORD,
    SERVER_MODE,
    DEBUG_MODE,
)


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


class RateLimiter:
    """Simple in-memory rate limiter to prevent brute force attacks."""
    def __init__(self, limit: int = 10, window: int = 60):
        self.limit = limit
        self.window = window
        self.failures: Dict[str, List[float]] = {}

    def is_blocked(self, ip: str) -> bool:
        """Check if an IP is currently blocked."""
        now = time.time()
        if ip in self.failures:
            # Filter old failures
            self.failures[ip] = [t for t in self.failures[ip] if t > now - self.window]
            if len(self.failures[ip]) >= self.limit:
                return True
        return False

    def record_failure(self, ip: str):
        """Record a failed attempt for an IP."""
        now = time.time()
        if ip not in self.failures:
            self.failures[ip] = []
        self.failures[ip].append(now)


# Global rate limiter instance (10 failures per minute)
auth_rate_limiter = RateLimiter(limit=10, window=60)


async def check_password(request: Request, x_password: Optional[str] = Header(default=None)):
    """FastAPI dependency to verify password header."""
    # Always allow MOCK mode
    if SERVER_MODE == "MOCK":
        return True

    pwd = get_password()

    # If a password is configured, enforce it regardless of REQUIRE_PASSWORD/DEBUG
    if pwd:
        client_ip = request.client.host if request.client else "unknown"

        # Check rate limit first
        if auth_rate_limiter.is_blocked(client_ip):
            raise HTTPException(
                status_code=429,
                detail="Too many failed login attempts. Please try again later."
            )

        if x_password is None or not secrets.compare_digest(x_password, pwd):
            auth_rate_limiter.record_failure(client_ip)
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
