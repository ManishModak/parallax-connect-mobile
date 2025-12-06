"""Password authentication for server endpoints."""

import getpass
from typing import Optional
from fastapi import Header, HTTPException

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


async def check_password(x_password: Optional[str] = Header(default=None)):
    """FastAPI dependency to verify password header."""
    # Auth disabled in mock/dev or when not required
    if SERVER_MODE == "MOCK" or DEBUG_MODE or not REQUIRE_PASSWORD:
        return True

    pwd = get_password()
    if not pwd:
        raise HTTPException(
            status_code=401,
            detail="Password required. Set SERVER_PASSWORD env and provide X-Password header.",
        )
    if x_password != pwd:
        raise HTTPException(status_code=401, detail="Invalid password")
    return True
