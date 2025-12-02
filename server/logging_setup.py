"""Logging configuration with file and console output."""

import glob
import logging
import json
import os
import sys
from datetime import datetime
from logging.handlers import RotatingFileHandler
from typing import Any

from .config import (
    LOG_DIR,
    LOG_FORMAT,
    LOG_DATE_FORMAT,
    LOG_LEVEL,
    LOG_JSON_FORMAT,
    SENSITIVE_FIELDS,
)


class JSONFormatter(logging.Formatter):
    """JSON log formatter with sensitive data redaction."""

    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON."""
        log_data = {
            "timestamp": datetime.fromtimestamp(record.created).isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }

        # Add extra fields from record
        if hasattr(record, "request_id"):
            log_data["request_id"] = record.request_id

        if hasattr(record, "extra_data"):
            log_data.update(self._redact_sensitive_data(record.extra_data))

        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_data)

    def _redact_sensitive_data(self, data: Any) -> Any:
        """Recursively redact sensitive fields from data."""
        if isinstance(data, dict):
            return {
                k: "******"
                if any(s in k.lower() for s in SENSITIVE_FIELDS)
                else self._redact_sensitive_data(v)
                for k, v in data.items()
            }
        elif isinstance(data, list):
            return [self._redact_sensitive_data(item) for item in data]
        return data


def cleanup_old_logs(keep_count: int = 5):
    """Remove old log files, keeping only the most recent ones."""
    try:
        log_files = glob.glob(os.path.join(LOG_DIR, "server_*.log*"))
        if len(log_files) <= keep_count:
            return

        log_files.sort(key=os.path.getmtime)
        for log_file in log_files[:-keep_count]:
            os.remove(log_file)
            print(f"🗑️ Deleted old log: {log_file}")
    except Exception as e:
        print(f"Failed to cleanup old logs: {e}")


def setup_logging():
    """Setup logging with console and file output."""
    os.makedirs(LOG_DIR, exist_ok=True)
    cleanup_old_logs(keep_count=5)

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    log_file = os.path.join(LOG_DIR, f"server_{timestamp}.log")

    # Determine log level
    # If DEBUG_MODE is enabled, force DEBUG level
    from .config import DEBUG_MODE

    if DEBUG_MODE:
        level = logging.DEBUG
        print("🔧 DEBUG MODE ENABLED: Detailed logging active")
    else:
        level = getattr(logging, LOG_LEVEL.upper(), logging.INFO)

    # Root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(level)

    # Clear existing handlers
    root_logger.handlers = []

    # Console Handler (Human readable)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(logging.Formatter(LOG_FORMAT, datefmt=LOG_DATE_FORMAT))
    root_logger.addHandler(console_handler)

    # File Handler (JSON or Text)
    file_handler = RotatingFileHandler(
        log_file,
        maxBytes=10 * 1024 * 1024,  # 10MB
        backupCount=5,
        encoding="utf-8",
    )

    if LOG_JSON_FORMAT:
        file_handler.setFormatter(JSONFormatter())
    else:
        file_handler.setFormatter(
            logging.Formatter(LOG_FORMAT, datefmt=LOG_DATE_FORMAT)
        )

    root_logger.addHandler(file_handler)

    logging.info(
        f"📝 Logging initialized. Level: {logging.getLevelName(level)}, JSON: {LOG_JSON_FORMAT}, Debug Mode: {DEBUG_MODE}"
    )
    logging.info(f"📂 Log file: {os.path.abspath(log_file)}")


def get_logger(name: str) -> logging.Logger:
    """Get a logger instance."""
    return logging.getLogger(name)
