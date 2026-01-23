"""Parallax Web UI proxy routes."""

from fastapi import APIRouter, Depends, Request, HTTPException
from fastapi.responses import HTMLResponse, Response, StreamingResponse

from ..auth import check_password
from ..config import PARALLAX_UI_URL, DEBUG_MODE
from ..logging_setup import get_logger
from ..services.http_client import get_async_http_client
from ..utils.security import validate_proxy_path

router = APIRouter()
logger = get_logger(__name__)


@router.get("/ui")
async def ui_redirect(_: bool = Depends(check_password)):
    """Redirect /ui to /ui/ for proper routing."""
    return HTMLResponse(
        content='<html><head><meta http-equiv="refresh" content="0;url=/ui/"></head></html>',
        status_code=200,
    )


@router.get("/ui/")
async def ui_index(_: bool = Depends(check_password)):
    """Serve the Parallax UI index page."""
    try:
        client = await get_async_http_client()
        resp = await client.get(f"{PARALLAX_UI_URL}/", timeout=10.0)

        content = resp.text
        content = content.replace('href="/', 'href="/ui/')
        content = content.replace("href='/", "href='/ui/")
        content = content.replace('src="/', 'src="/ui/')
        content = content.replace("src='/", "src='/ui/")

        return HTMLResponse(content=content, status_code=resp.status_code)
    except Exception as e:
        logger.error(f"❌ UI proxy error: {e}")
        error_msg = str(e) if DEBUG_MODE else "An unexpected error occurred."
        return HTMLResponse(
            content=f"<h1>Cannot connect to Parallax UI</h1><p>Error: {error_msg}</p><p>Make sure Parallax is running on port 3001.</p>",
            status_code=503,
        )


@router.get("/ui/{path:path}")
async def ui_proxy(path: str, request: Request, _: bool = Depends(check_password)):
    """Proxy all Parallax UI requests (assets, API calls, etc.)."""
    # Security: Prevent path traversal
    if not validate_proxy_path(path):
        logger.warning(f"⚠️ Blocked potential path traversal in UI proxy: {path}")
        raise HTTPException(status_code=400, detail="Invalid path")

    try:
        target_url = f"{PARALLAX_UI_URL}/{path}"
        if request.query_params:
            target_url += f"?{request.query_params}"

        client = await get_async_http_client()
        resp = await client.get(target_url, timeout=15.0)
        content_type = resp.headers.get("content-type", "application/octet-stream")

        if "text/html" in content_type:
            content = resp.text
            content = content.replace('href="/', 'href="/ui/')
            content = content.replace("href='/", "href='/ui/")
            content = content.replace('src="/', 'src="/ui/')
            content = content.replace("src='/", "src='/ui/")
            return HTMLResponse(content=content, status_code=resp.status_code)

        return Response(
            content=resp.content,
            status_code=resp.status_code,
            media_type=content_type,
        )
    except Exception as e:
        logger.error(f"❌ UI proxy error for {path}: {e}")
        error_msg = str(e) if DEBUG_MODE else "An unexpected error occurred."
        return Response(content=error_msg, status_code=503)


@router.api_route("/ui-api/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def ui_api_proxy(path: str, request: Request, _: bool = Depends(check_password)):
    """Proxy API calls from the Parallax UI."""
    # Security: Prevent path traversal
    if not validate_proxy_path(path):
        logger.warning(f"⚠️ Blocked potential path traversal in UI API proxy: {path}")
        raise HTTPException(status_code=400, detail="Invalid path")

    try:
        target_url = f"{PARALLAX_UI_URL}/{path}"
        if request.query_params:
            target_url += f"?{request.query_params}"

        client = await get_async_http_client()
        body = await request.body()

        if len(body) > 1_000_000:
            raise HTTPException(status_code=413, detail="Request body too large (>1MB)")

        resp = await client.request(
            method=request.method,
            url=target_url,
            content=body if body else None,
            headers={
                k: v
                for k, v in request.headers.items()
                if k.lower() not in ["host", "content-length"]
            },
            timeout=20.0,
        )

        content_type = resp.headers.get("content-type", "application/json")

        # Handle SSE streams
        if (
            "text/event-stream" in content_type
            or "application/x-ndjson" in content_type
        ):

            async def stream_response():
                stream_client = await get_async_http_client()
                async with stream_client.stream(
                    method=request.method,
                    url=target_url,
                    content=body if body else None,
                    timeout=20.0,
                ) as stream_resp:
                    async for chunk in stream_resp.aiter_bytes():
                        yield chunk

            return StreamingResponse(stream_response(), media_type=content_type)

        return Response(
            content=resp.content,
            status_code=resp.status_code,
            media_type=content_type,
        )
    except Exception as e:
        logger.error(f"❌ UI API proxy error for {path}: {e}")
        error_msg = str(e) if DEBUG_MODE else "An unexpected error occurred."
        return Response(content=error_msg, status_code=503)
