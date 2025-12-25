"""FastAPI application factory."""

from fastapi import FastAPI

from .apis import health_router, chat_router, models_router, ui_router, logs_router
from .startup import on_startup
from .logging_setup import setup_logging
from .middleware.log_middleware import LogMiddleware
from .middleware.security_middleware import SecurityHeadersMiddleware


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    # Initialize logging
    setup_logging()

    app = FastAPI(
        title="Parallax Connect Server",
        description="API server for Parallax AI service",
        version="1.0.0",
    )

    # Register startup event
    app.add_event_handler("startup", on_startup)

    # Initialize Service Manager
    from .services.service_manager import service_manager

    app.add_event_handler("startup", service_manager.initialize_services)
    app.add_event_handler("shutdown", service_manager.shutdown)

    # Add Middleware
    app.add_middleware(LogMiddleware)
    app.add_middleware(SecurityHeadersMiddleware)

    # Include routers
    app.include_router(health_router)
    app.include_router(chat_router)
    app.include_router(models_router)
    app.include_router(ui_router)
    app.include_router(logs_router)
    from .apis.search import router as search_router

    app.include_router(search_router)

    return app


# Create app instance
app = create_app()
