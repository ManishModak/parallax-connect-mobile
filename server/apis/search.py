"""
Search API endpoints.
"""

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, Dict, Any

from ..services.web_search import WebSearchService
from ..logging_setup import get_logger

router = APIRouter()
logger = get_logger(__name__)
search_service = WebSearchService()


class SearchRequest(BaseModel):
    query: str
    depth: str = "normal"  # normal, deep, deeper


@router.post("/search")
async def search_endpoint(request: SearchRequest):
    """
    Execute a web search.
    """
    try:
        results = await search_service.search(request.query, request.depth)
        return results
    except Exception as e:
        logger.error(f"❌ Search endpoint error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
