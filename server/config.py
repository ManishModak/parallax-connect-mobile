"""Server configuration and constants."""

from typing import Optional

# Server Mode: "MOCK" or "PROXY"
SERVER_MODE = "PROXY"

# Parallax Service URLs
PARALLAX_SERVICE_URL = "http://localhost:3001/v1/chat/completions"
PARALLAX_UI_URL = "http://localhost:3001"

# Logging
LOG_DIR = "applogs"
LOG_FORMAT = "%(asctime)s [%(levelname)s] %(message)s"
LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

# Global password (set at runtime)
PASSWORD: Optional[str] = None


def set_password(pwd: Optional[str]):
    """Set the server password."""
    global PASSWORD
    PASSWORD = pwd


def get_password() -> Optional[str]:
    """Get the current server password."""
    return PASSWORD
