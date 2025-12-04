"""API route modules."""

from .health import router as health_router
from .chat import router as chat_router
from .models import router as models_router
from .ui_proxy import router as ui_router
from .logs import router as logs_router

__all__ = ["health_router", "chat_router", "models_router", "ui_router", "logs_router"]
