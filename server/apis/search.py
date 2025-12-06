"""
Search API endpoints.
"""

from fastapi import APIRouter, Request, Depends
from pydantic import BaseModel

from ..auth import check_password
from ..services.service_manager import service_manager
from ..logging_setup import get_logger
from ..utils.error_handler import handle_service_error

router = APIRouter()
logger = get_logger(__name__)


class SearchRequest(BaseModel):
    query: str
    depth: str = "normal"  # normal, deep, deeper


@router.post("/search")
async def search_endpoint(
    request: Request, search_req: SearchRequest, _: bool = Depends(check_password)
):
    """
    Execute a web search.
    """
    request_id = getattr(request.state, "request_id", "unknown")

    try:
        search_service = service_manager.get_web_search_service()
        results = await search_service.search(search_req.query, search_req.depth)
        return results
    except Exception as e:
        return handle_service_error(e, "Search Endpoint", request_id)
