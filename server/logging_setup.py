"""Logging configuration with file and console output."""

import glob
import logging
import os
from datetime import datetime
from logging.handlers import RotatingFileHandler

from .config import LOG_DIR, LOG_FORMAT, LOG_DATE_FORMAT


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

    logging.basicConfig(
        level=logging.INFO,
        format=LOG_FORMAT,
        datefmt=LOG_DATE_FORMAT,
        handlers=[
            logging.StreamHandler(),
            RotatingFileHandler(
                log_file,
                maxBytes=5 * 1024 * 1024,
                backupCount=3,
                encoding="utf-8",
            ),
        ],
    )

    logging.info(f"📝 Logging to: {os.path.abspath(log_file)}")


def get_logger(name: str) -> logging.Logger:
    """Get a logger instance."""
    return logging.getLogger(name)
