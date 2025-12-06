"""API endpoint for receiving mobile app logs."""

import os
import glob
import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field

from ..config import LOG_DIR
from ..auth import check_password

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/logs", tags=["logs"])


class LogUploadRequest(BaseModel):
    """Request body for log upload."""
    device_id: str = Field(..., min_length=1, max_length=100)
    device_name: Optional[str] = Field(None, max_length=100)
    logs: str = Field(..., min_length=1, max_length=500_000)  # 500KB max


class LogUploadResponse(BaseModel):
    """Response for log upload."""
    success: bool
    message: str
    filename: Optional[str] = None


@router.post("/upload", response_model=LogUploadResponse)
async def upload_logs(
    request: LogUploadRequest, _: bool = Depends(check_password)
) -> LogUploadResponse:
    """
    Receive and store logs from mobile app.
    
    Saves logs to applogs/mobile_<device_id>_<timestamp>.log
    """
    try:
        # Ensure logs directory exists
        os.makedirs(LOG_DIR, exist_ok=True)
        _prune_mobile_logs(keep=20)
        
        # Generate filename
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        safe_device_id = "".join(c if c.isalnum() else "_" for c in request.device_id)
        filename = f"mobile_{safe_device_id}_{timestamp}.log"
        filepath = os.path.join(LOG_DIR, filename)
        # Guard against excessively large payloads (additional to Pydantic cap)
        if len(request.logs.encode("utf-8")) > 600_000:
            raise HTTPException(
                status_code=413, detail="Log payload too large (max 600KB)"
            )

        # Write logs to file
        with open(filepath, "w", encoding="utf-8") as f:
            # Add header with device info
            f.write("=== Mobile Logs ===\n")
            f.write(f"Device ID: {request.device_id}\n")
            if request.device_name:
                f.write(f"Device Name: {request.device_name}\n")
            f.write(f"Received: {datetime.now().isoformat()}\n")
            f.write(f"{'=' * 40}\n\n")
            f.write(request.logs)
        
        logger.info(f"Received logs from device {request.device_id}, saved to {filename}")
        
        return LogUploadResponse(
            success=True,
            message="Logs uploaded successfully",
            filename=filename
        )
        
    except Exception as e:
        logger.error(f"Failed to save logs from {request.device_id}: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to save logs: {str(e)}"
        )


def _prune_mobile_logs(keep: int = 20) -> None:
    """Keep only the newest N mobile logs to avoid unbounded growth."""
    try:
        log_files = glob.glob(os.path.join(LOG_DIR, "mobile_*.log"))
        if len(log_files) <= keep:
            return

        log_files.sort(key=os.path.getmtime, reverse=True)
        for old_file in log_files[keep:]:
            try:
                os.remove(old_file)
            except OSError:
                continue
    except Exception:
        # Pruning is best-effort; do not block uploads
        pass
