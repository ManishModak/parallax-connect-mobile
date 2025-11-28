"""Password authentication for server endpoints."""

import getpass
from typing import Optional
from fastapi import Header, HTTPException

from ..config import get_password, set_password


def setup_password():
    """Prompt user for optional password protection with confirmation."""
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
    pwd = get_password()
    if pwd and x_password != pwd:
        raise HTTPException(status_code=401, detail="Invalid password")
    return True
