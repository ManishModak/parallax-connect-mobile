"""
Service Manager.
Centralizes initialization and access to core services to prevent redundancy.
"""

from typing import Optional

from ..config import PARALLAX_SERVICE_URL
from ..logging_setup import get_logger
from .parallax import ParallaxClient
from .web_search import WebSearchService
from .search_router import SearchRouter

logger = get_logger(__name__)


class ServiceManager:
    """Singleton manager for server services."""

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(ServiceManager, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return

        self.parallax_client: Optional[ParallaxClient] = None
        self.web_search_service: Optional[WebSearchService] = None
        self.search_router: Optional[SearchRouter] = None
        self._initialized = True
        logger.info("🛠️ Service Manager initialized")

    def initialize_services(self):
        """Initialize all core services."""
        if self.parallax_client:
            logger.info("⚠️ Services already initialized, skipping.")
            return

        logger.info("🚀 Initializing core services...")

        # 1. Parallax Client
        self.parallax_client = ParallaxClient(PARALLAX_SERVICE_URL)

        # 2. Web Search Service
        self.web_search_service = WebSearchService()

        # 3. Search Router (depends on Parallax Client)
        self.search_router = SearchRouter(self.parallax_client)

        logger.info("✅ All services initialized successfully")

    def get_parallax_client(self) -> ParallaxClient:
        """Get the ParallaxClient instance."""
        if not self.parallax_client:
            self.initialize_services()
        return self.parallax_client

    def get_web_search_service(self) -> WebSearchService:
        """Get the WebSearchService instance."""
        if not self.web_search_service:
            self.initialize_services()
        return self.web_search_service

    def get_search_router(self) -> SearchRouter:
        """Get the SearchRouter instance."""
        if not self.search_router:
            self.initialize_services()
        return self.search_router


# Global instance
service_manager = ServiceManager()
