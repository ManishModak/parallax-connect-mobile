"""Server configuration and constants."""

import os
from typing import Optional

# Server Mode: "MOCK" or "PROXY"
SERVER_MODE = os.getenv("SERVER_MODE", "NORMAL").upper()

# Parallax Service URLs
PARALLAX_BASE_URL = os.getenv("PARALLAX_BASE_URL", "http://localhost:3001")
PARALLAX_SERVICE_URL = os.getenv(
    "PARALLAX_SERVICE_URL", f"{PARALLAX_BASE_URL}/v1/chat/completions"
)
PARALLAX_UI_URL = os.getenv("PARALLAX_UI_URL", PARALLAX_BASE_URL)


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

# Password requirement (opt-in; disabled by default and in MOCK/DEBUG)
REQUIRE_PASSWORD = (
    os.getenv("REQUIRE_PASSWORD", "false").lower() == "true"
    and SERVER_MODE != "MOCK"
    and not DEBUG_MODE
)

# OCR Configuration
# Set to "true" to enable server-side OCR (requires ~100MB model download on first use)
OCR_ENABLED = os.getenv("OCR_ENABLED", "false").lower() == "true"
OCR_ENGINE = os.getenv("OCR_ENGINE", "easyocr")  # 'paddleocr' or 'easyocr'
OCR_LANGUAGES = os.getenv("OCR_LANGUAGES", "en").split(",")

# Document Processing Configuration
DOC_ENABLED = os.getenv("DOC_ENABLED", "false").lower() == "true"
DOC_ENGINE = os.getenv("DOC_ENGINE", "pymupdf")  # 'pymupdf' or 'pdfplumber'

# Cache Configuration
MODEL_CACHE_TTL = int(os.getenv("MODEL_CACHE_TTL", "60"))  # seconds

# Web Search controls
SEARCH_RATE_LIMIT_PER_MIN = int(os.getenv("SEARCH_RATE_LIMIT_PER_MIN", "30"))
SEARCH_ALLOWED_DOMAINS = [
    d.strip().lower()
    for d in os.getenv("SEARCH_ALLOWED_DOMAINS", "").split(",")
    if d.strip()
]

# Timeouts (seconds)
TIMEOUT_DEFAULT = 60.0
TIMEOUT_FAST = 5.0
TIMEOUT_SEARCH = 15.0
TIMEOUT_STREAM_CONNECT = 10.0
TIMEOUT_STREAM_CHUNK = 30.0

# Request Validation Limits
# NOTE: MAX_PROMPT_LENGTH is high to support base64-encoded documents (e.g., PDFs)
# Base64 increases size by ~33%, so a 37MB PDF becomes ~50M chars
MAX_PROMPT_LENGTH = int(os.getenv("MAX_PROMPT_LENGTH", "50000000"))  # 50M characters
MAX_SYSTEM_PROMPT_LENGTH = int(os.getenv("MAX_SYSTEM_PROMPT_LENGTH", "100000"))  # 100K
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
