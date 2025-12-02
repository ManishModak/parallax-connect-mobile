"""Server configuration and constants."""

import os
from typing import Optional

# Server Mode: "MOCK" or "PROXY"
SERVER_MODE = os.getenv("SERVER_MODE", "PROXY").upper()

# Parallax Service URLs
PARALLAX_SERVICE_URL = os.getenv(
    "PARALLAX_SERVICE_URL", "http://localhost:3001/v1/chat/completions"
)
PARALLAX_UI_URL = os.getenv("PARALLAX_UI_URL", "http://localhost:3001")

# Logging
LOG_DIR = "applogs"
LOG_FORMAT = "%(asctime)s [%(levelname)s] %(message)s"
LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
LOG_JSON_FORMAT = False
SENSITIVE_FIELDS = ["password", "token", "api_key", "authorization", "secret"]

# Debug & Performance
DEBUG_MODE = os.getenv("DEBUG_MODE", "false").lower() == "true"
ENABLE_PERFORMANCE_METRICS = (
    os.getenv("ENABLE_PERFORMANCE_METRICS", "false").lower() == "true" or DEBUG_MODE
)

# Cache Configuration
MODEL_CACHE_TTL = int(os.getenv("MODEL_CACHE_TTL", "60"))  # seconds

# Timeouts (seconds)
TIMEOUT_DEFAULT = 60.0
TIMEOUT_FAST = 5.0
TIMEOUT_SEARCH = 15.0

# Request Validation Limits
MAX_PROMPT_LENGTH = int(os.getenv("MAX_PROMPT_LENGTH", "100000"))  # characters
MAX_SYSTEM_PROMPT_LENGTH = int(os.getenv("MAX_SYSTEM_PROMPT_LENGTH", "50000"))
MAX_MESSAGE_HISTORY = int(os.getenv("MAX_MESSAGE_HISTORY", "100"))  # messages

# Global password (set at runtime)
PASSWORD: Optional[str] = os.getenv("SERVER_PASSWORD")


def set_password(pwd: Optional[str]):
    """Set the server password."""
    global PASSWORD
    PASSWORD = pwd


def get_password() -> Optional[str]:
    """Get the current server password."""
    return PASSWORD
