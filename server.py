import asyncio
import getpass
import glob
import json
import os
import re
import socket
import uvicorn
import httpx
import qrcode
import logging
from datetime import datetime
from logging.handlers import RotatingFileHandler
from fastapi import (
    Depends,
    FastAPI,
    File,
    Form,
    Header,
    HTTPException,
    Request,
    UploadFile,
)
from fastapi.responses import HTMLResponse, Response, StreamingResponse
from pydantic import BaseModel
from pyngrok import ngrok
from typing import List, Optional

# Parallax UI Base URL
PARALLAX_UI_URL = "http://localhost:3001"

# Configure logging with file output
LOG_DIR = "applogs"
LOG_FORMAT = "%(asctime)s [%(levelname)s] %(message)s"
LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"


def setup_logging():
    """Setup logging with console and file output."""
    # Create applogs directory if it doesn't exist
    os.makedirs(LOG_DIR, exist_ok=True)

    # Cleanup old log files (keep last 5)
    cleanup_old_logs(keep_count=5)

    # Create log filename with timestamp
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    log_file = os.path.join(LOG_DIR, f"server_{timestamp}.log")

    # Configure root logger
    logging.basicConfig(
        level=logging.INFO,
        format=LOG_FORMAT,
        datefmt=LOG_DATE_FORMAT,
        handlers=[
            logging.StreamHandler(),  # Console output
            RotatingFileHandler(
                log_file,
                maxBytes=5 * 1024 * 1024,  # 5 MB
                backupCount=3,
                encoding="utf-8",
            ),
        ],
    )

    logging.info(f"📝 Logging to: {os.path.abspath(log_file)}")


def cleanup_old_logs(keep_count: int = 5):
    """Remove old log files, keeping only the most recent ones."""
    try:
        log_files = glob.glob(os.path.join(LOG_DIR, "server_*.log*"))
        if len(log_files) <= keep_count:
            return

        # Sort by modification time (oldest first)
        log_files.sort(key=os.path.getmtime)

        # Delete oldest files
        for log_file in log_files[:-keep_count]:
            os.remove(log_file)
            print(f"🗑️ Deleted old log: {log_file}")
    except Exception as e:
        print(f"Failed to cleanup old logs: {e}")


# Initialize logging
setup_logging()
logger = logging.getLogger(__name__)

# --- CONFIGURATION ---
# Options: "MOCK", "PROXY"
# - MOCK: Returns dummy data (for UI Dev).
# - PROXY: Forwards requests to running Parallax Service (localhost:3002).
SERVER_MODE = "PROXY"
PASSWORD: Optional[str] = None

# Parallax Service Endpoint (OpenAI Compatible)
# NOTE: Port 3001 is the scheduler which provides the API
# Port 3002 is only for the web chat UI (when running 'parallax chat')
PARALLAX_SERVICE_URL = "http://localhost:3001/v1/chat/completions"

app = FastAPI()


def setup_password():
    """Prompt user for optional password protection with confirmation."""
    global PASSWORD

    try:
        choice = input("\n🔒 Set a password for this server? (y/n): ").strip().lower()
    except EOFError:
        choice = "n"

    if choice == "y":
        password = getpass.getpass("Enter password: ").strip()
        if not password:
            PASSWORD = None
            print("⚠️  Empty password. Server remains open.\n")
            return
            
        # Confirm password
        confirm_password = getpass.getpass("Retype password: ").strip()
        
        if password != confirm_password:
            print("❌ Passwords do not match. Server remains open.\n")
            PASSWORD = None
            return
            
        PASSWORD = password
        print("✅ Password protection enabled\n")
    else:
        PASSWORD = None
        print("⚠️  No password set. Server is open.\n")


async def check_password(x_password: Optional[str] = Header(default=None)):
    if PASSWORD and x_password != PASSWORD:
        raise HTTPException(status_code=401, detail="Invalid password")

    return True


def get_local_ip():
    """Get the local IP address of this machine."""
    try:
        # Connect to an external server (doesn't actually send data) to get the interface IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def print_qr(url):
    """Generate and print a QR code for the given URL to the terminal."""
    qr = qrcode.QRCode(version=1, box_size=1, border=1)
    qr.add_data(url)
    qr.make(fit=True)
    qr.print_ascii(invert=True)


@app.on_event("startup")
async def startup_event():
    logger.info(f"🚀 Server Starting... MODE: {SERVER_MODE}")

    # Test Parallax connection if in PROXY mode
    if SERVER_MODE == "PROXY":
        logger.info(f"Testing connection to Parallax at {PARALLAX_SERVICE_URL}...")
        try:
            async with httpx.AsyncClient() as client:
                # Use /model/list endpoint (no /health endpoint exists in Parallax)
                resp = await client.get("http://localhost:3001/model/list", timeout=5.0)
                if resp.status_code == 200:
                    logger.info("✅ Parallax connection successful")
                else:
                    logger.warning(f"⚠️ Parallax returned status {resp.status_code}")
        except Exception as e:
            logger.warning(f"⚠️ Cannot reach Parallax: {e}")
            logger.warning("Make sure Parallax is running: parallax run")

    setup_password()

    # 1. Get Local URL
    local_ip = get_local_ip()
    local_url = f"http://{local_ip}:8000"

    # 2. Try to start Ngrok Tunnel
    public_url = None
    try:
        # pyngrok automatically loads the auth token from the config file
        http_tunnel = ngrok.connect(8000)
        public_url = http_tunnel.public_url
    except Exception as e:
        error_msg = str(e).lower()
        if "authtoken" in error_msg or "authentication" in error_msg:
            print("⚠️ Ngrok Auth Token not found. Skipping Cloud Tunnel.")
            print("   Run: ngrok config add-authtoken <TOKEN> to enable Cloud Mode.")
        else:
            print(f"⚠️ Could not start Ngrok: {e}")

    # 3. Display Connection Info & QR Code
    print("\n" + "=" * 50)
    print("📲 CONNECT YOUR APP")
    print("=" * 50)

    if public_url:
        print("\n🌍 CLOUD MODE (Recommended)")
        print(f"URL: {public_url}")
        print("Scan this QR code to connect:\n")
        print_qr(public_url)
        print("\n" + "-" * 50)

    print("\n🏠 LOCAL MODE (Same Wi-Fi only)")
    print(f"URL: {local_url}")
    print("Scan this QR code to connect:\n")
    print_qr(local_url)

    print("\n" + "-" * 50)
    print("\n🖥️  PARALLAX WEB UI")
    print(f"Local:  {local_url}/ui/")
    if public_url:
        print(f"Cloud:  {public_url}/ui/")
    print("(Access the full Parallax dashboard remotely)")

    print("=" * 50 + "\n")


@app.get("/", dependencies=[Depends(check_password)])
def home():
    logger.info("📍 Root endpoint accessed")
    return {"status": "online", "mode": SERVER_MODE, "device": "Server Node"}


@app.get("/healthz")
def health_check():
    """Public health check that doesn't require a password."""
    return {"status": "ok"}


class ChatRequest(BaseModel):
    """
    Chat request model with support for advanced AI sampling parameters.

    These parameters control how the AI generates responses, affecting
    creativity, randomness, repetition, and output format.

    PARALLAX SUPPORT STATUS:
    ========================
    Currently WORKING in Parallax executor:
      - max_tokens, temperature, top_p, top_k

    NOT YET IMPLEMENTED in Parallax executor (defined but ignored):
      - repetition_penalty, presence_penalty, frequency_penalty, stop

    These unsupported params are kept for future compatibility when Parallax
    adds support. See: parallax/server/executor.py lines 867-878
    """

    # === REQUIRED ===
    prompt: str  # The user's message/question
    system_prompt: Optional[str] = None  # Optional system instructions
    model: Optional[str] = None  # Model ID to use (defaults to "default")

    # === CONVERSATION HISTORY (FOR MULTI-TURN CHAT) ===
    messages: Optional[List[dict]] = None
    """
    Conversation history for multi-turn chat continuation.
    Format: [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]
    - If provided, enables context-aware responses using previous messages
    - If None/empty, falls back to single prompt mode (backwards compatible)
    """

    # === BASIC PARAMETERS (SUPPORTED) ===
    max_tokens: int = 8192
    """
    Maximum number of tokens (words/pieces) to generate.
    STATUS: SUPPORTED by Parallax
    - Default: 8192
    - Range: 1 to model's max context length
    """

    # === CREATIVITY CONTROLS (SUPPORTED) ===
    temperature: float = 0.7
    """
    Controls randomness/creativity in responses.
    STATUS: SUPPORTED by Parallax
    - Default: 0.7 (balanced)
    - Range: 0.0 to 2.0
    - 0.0 becomes greedy sampling (top_k=1)
    """

    top_p: float = 0.9
    """
    Nucleus sampling - considers only top tokens whose probabilities sum to this value.
    STATUS: SUPPORTED by Parallax
    - Default: 0.9
    - Range: 0.0 to 1.0
    """

    top_k: int = -1
    """
    Limits sampling to the top K most likely tokens.
    STATUS: SUPPORTED by Parallax
    - Default: -1 (disabled)
    - Range: -1 (off) or 1 to 100+
    """

    # === REPETITION CONTROLS (NOT YET SUPPORTED) ===
    repetition_penalty: float = 1.0
    """
    Penalizes tokens that have already appeared.
    STATUS: NOT YET SUPPORTED - Parallax executor does not parse this parameter
    - Default: 1.0 (no penalty)
    - Range: 0.0 to 2.0
    - Kept for future compatibility
    """

    presence_penalty: float = 0.0
    """
    Penalizes tokens based on whether they appear in the text.
    STATUS: NOT YET SUPPORTED - Parallax executor does not parse this parameter
    - Default: 0.0
    - Range: -2.0 to 2.0
    - Kept for future compatibility
    """

    frequency_penalty: float = 0.0
    """
    Penalizes tokens based on how often they appear.
    STATUS: NOT YET SUPPORTED - Parallax executor does not parse this parameter
    - Default: 0.0
    - Range: -2.0 to 2.0
    - Kept for future compatibility
    """

    # === OUTPUT CONTROLS (NOT YET SUPPORTED) ===
    stop: List[str] = []
    """
    List of strings where generation should stop.
    STATUS: NOT YET SUPPORTED - Parallax executor does not parse this parameter
    - Default: [] (empty, use model's default stop tokens)
    - Kept for future compatibility
    """


@app.get("/status", dependencies=[Depends(check_password)])
async def status_endpoint():
    """Check server and Parallax connectivity status."""
    status = {
        "server": "online",
        "mode": SERVER_MODE,
        "timestamp": datetime.now().isoformat(),
    }

    if SERVER_MODE == "PROXY":
        try:
            async with httpx.AsyncClient() as client:
                # Use /model/list endpoint (no /health endpoint exists in Parallax)
                resp = await client.get("http://localhost:3001/model/list", timeout=5.0)
                if resp.status_code == 200:
                    status["parallax"] = "connected"
                    logger.info("✅ Parallax status check: connected")
                else:
                    status["parallax"] = "error"
                    status["parallax_error"] = f"Status {resp.status_code}"
                    logger.warning(f"⚠️ Parallax returned status {resp.status_code}")
        except Exception as e:
            status["parallax"] = "disconnected"
            status["parallax_error"] = str(e)
            logger.error(f"❌ Parallax status check failed: {e}")

    return status


@app.get("/models", dependencies=[Depends(check_password)])
async def models_endpoint():
    """
    Returns available and active models from Parallax.
    
    IMPORTANT: Parallax runs ONE model at a time. The model is set when the
    scheduler is initialized via the Web UI or /scheduler/init endpoint.
    The 'model' field in chat requests is IGNORED - it uses the active model.
    
    Parallax endpoints:
    - /model/list: returns {type: "model_list", data: [{name, vram_gb}, ...]} - all SUPPORTED models
    - /cluster/status: SSE stream with {data: {model_name: "..."}} - the ACTIVE model
    
    We return:
    - models: list of supported models
    - active: the currently running model (from cluster status)
    - default: same as active, or first model if no active
    """
    if SERVER_MODE == "MOCK":
        return {
            "models": [
                {"id": "mock-model", "name": "Mock Model", "context_length": 4096, "vram_gb": 8}
            ],
            "active": "mock-model",
            "default": "mock-model",
        }

    active_model = None
    models = []
    
    try:
        async with httpx.AsyncClient() as client:
            # Get supported models list
            resp = await client.get("http://localhost:3001/model/list", timeout=5.0)
            if resp.status_code == 200:
                response_data = resp.json()
                # Parallax returns: {type: "model_list", data: [{name, vram_gb}, ...]}
                # Fallback to OpenAI standard format: {data: [{id, ...}]} or just [{id, ...}]
                raw_models = response_data.get("data", [])
                # If data is empty, try treating response as direct array (OpenAI /v1/models format)
                if not raw_models and isinstance(response_data, list):
                    raw_models = response_data
                # Also handle OpenAI format where models have 'id' instead of 'name'
                if raw_models and "id" in raw_models[0] and "name" not in raw_models[0]:
                    raw_models = [{"name": m.get("id"), **m} for m in raw_models]
                
                # Normalize model format for the app
                models = [
                    {
                        "id": m.get("name", "unknown"),
                        "name": m.get("name", "Unknown Model"),
                        "context_length": 32768,
                        "vram_gb": m.get("vram_gb", 0),
                    }
                    for m in raw_models
                ]
            
            # Get active model from cluster status (SSE - read first line only)
            try:
                async with client.stream("GET", "http://localhost:3001/cluster/status", timeout=2.0) as stream:
                    async for line in stream.aiter_lines():
                        if line.strip():
                            # Handle SSE format: "data: {...}"
                            line_data = line
                            if line.startswith("data: "):
                                line_data = line[6:]
                            if line_data == "[DONE]":
                                break
                            try:
                                status_data = json.loads(line_data)
                                # Parallax format: {data: {model_name: "..."}}
                                active_model = status_data.get("data", {}).get("model_name")
                                # Fallback: try direct model_name field
                                if not active_model:
                                    active_model = status_data.get("model_name")
                                # Fallback: try model field (OpenAI standard)
                                if not active_model:
                                    active_model = status_data.get("model")
                                if active_model:
                                    break
                            except json.JSONDecodeError:
                                continue
            except Exception as e:
                logger.debug(f"Could not get cluster status: {e}")
                
    except Exception as e:
        logger.error(f"❌ Failed to fetch models: {e}")

    # Determine default: active model if set, otherwise first in list
    default_model = active_model or (models[0]["id"] if models else "default")
    
    logger.info(f"📋 Models: {len(models)} available, active: {active_model or 'none'}")
    
    return {
        "models": models,
        "active": active_model,  # Currently running model (None if scheduler not initialized)
        "default": default_model,
    }


@app.get("/info", dependencies=[Depends(check_password)])
async def info_endpoint():
    """
    Returns server capabilities for dynamic feature configuration.
    
    The mobile app uses this to enable/disable features based on:
    - VRAM availability (Full Multimodal requires >=16GB)
    - Vision model support
    - Document processing support
    - Model context window size
    """
    info = {
        "server_version": "1.0.0",
        "mode": SERVER_MODE,
        "capabilities": {
            # Default conservative values - features disabled until verified
            "vram_gb": 0,
            "vision_supported": False,
            "document_processing": False,
            "max_context_window": 4096,
            "multimodal_supported": False,
        },
        "timestamp": datetime.now().isoformat(),
    }

    if SERVER_MODE == "MOCK":
        # Mock mode: return limited capabilities
        info["capabilities"] = {
            "vram_gb": 8,
            "vision_supported": False,
            "document_processing": False,
            "max_context_window": 4096,
            "multimodal_supported": False,
        }
        return info

    # PROXY mode: query Parallax for actual capabilities
    # NOTE: Parallax API provides:
    # - /model/list: returns {type, data: [{name, vram_gb}, ...]}
    # - /cluster/status: SSE stream (not useful for one-time query)
    # - Vision/multimodal is NOT currently supported by Parallax executor
    # - Document processing is done client-side (Edge OCR / Smart Context)
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get("http://localhost:3001/model/list", timeout=5.0)
            
            if resp.status_code == 200:
                model_data = resp.json()
                # Parallax returns: {type: "model_list", data: [{name, vram_gb}, ...]}
                # Fallback to OpenAI standard format or direct array
                models = model_data.get("data", [])
                if not models and isinstance(model_data, list):
                    models = model_data
                # Handle OpenAI format where models have 'id' instead of 'name'
                if models and isinstance(models[0], dict):
                    if "id" in models[0] and "name" not in models[0]:
                        models = [{"name": m.get("id"), **m} for m in models]
                
                if models:
                    # Get max VRAM requirement from available models
                    # This gives us an idea of what the cluster can handle
                    max_vram = max((m.get("vram_gb", 0) for m in models), default=0)
                    
                    # Estimate available VRAM based on largest model supported
                    # If cluster can run a 16GB model, it likely has 16GB+ VRAM
                    info["capabilities"]["vram_gb"] = max_vram if max_vram > 0 else 8
                    
                    # Vision/multimodal: NOT supported by Parallax currently
                    # The executor doesn't process images - only text
                    info["capabilities"]["vision_supported"] = False
                    info["capabilities"]["multimodal_supported"] = False
                    
                    # Document processing: This is done client-side via:
                    # - Edge OCR (ML Kit on device)
                    # - Smart Context (chunking before sending)
                    # Server just needs decent context window for text
                    # Most models support 4K-32K context
                    info["capabilities"]["document_processing"] = True
                    info["capabilities"]["max_context_window"] = 32768  # Most modern models
                    
                    # Add model info for reference
                    info["active_models"] = [m.get("name", "unknown") for m in models[:5]]
                
                logger.info(f"📊 Server capabilities: {info['capabilities']}")
            else:
                logger.warning(f"⚠️ Could not fetch model info: {resp.status_code}")
                
    except Exception as e:
        logger.error(f"❌ Failed to fetch server capabilities: {e}")
        # Return conservative defaults on error

    return info


@app.post("/chat", dependencies=[Depends(check_password)])
async def chat_endpoint(request: ChatRequest):
    request_id = datetime.now().strftime("%Y%m%d%H%M%S%f")
    logger.info(f"📝 [{request_id}] Received chat request: {request.prompt[:50]}...")

    if SERVER_MODE == "MOCK":
        logger.info(f"📤 [{request_id}] Returning MOCK response")
        return {
            "response": f"[MOCK] Server received: '{request.prompt}'. \n\nThis is a simulated response."
        }

    elif SERVER_MODE == "PROXY":
        # Forward to Parallax Service (OpenAI API)
        start_time = datetime.now()
        try:
            logger.info(
                f"🔄 [{request_id}] Forwarding to Parallax at {PARALLAX_SERVICE_URL}"
            )

            async with httpx.AsyncClient() as client:
                # Build messages array for Parallax
                # Supports both multi-turn (with history) and single-turn modes
                if request.messages:
                    # Multi-turn mode: use provided conversation history
                    messages = list(request.messages)
                    # Prepend system prompt if provided
                    if request.system_prompt:
                        messages.insert(
                            0, {"role": "system", "content": request.system_prompt}
                        )
                    logger.info(
                        f"📜 [{request_id}] Using conversation history ({len(messages)} messages)"
                    )
                else:
                    # Single-turn mode (backwards compatible)
                    messages = []
                    if request.system_prompt:
                        messages.append(
                            {"role": "system", "content": request.system_prompt}
                        )
                    messages.append({"role": "user", "content": request.prompt})

                # Parallax expects sampling params nested inside "sampling_params" object
                # Currently supported by Parallax executor: temperature, top_p, top_k
                # (repetition_penalty, presence_penalty, frequency_penalty, stop are TODO in Parallax)
                payload = {
                    "model": request.model or "default",
                    "messages": messages,
                    "stream": False,
                    "max_tokens": request.max_tokens,
                    "sampling_params": {
                        "temperature": request.temperature,
                        "top_p": request.top_p,
                        "top_k": request.top_k,
                        # Below params are defined in Parallax but not yet parsed by executor
                        # Keeping them here for future compatibility when Parallax adds support
                        "repetition_penalty": request.repetition_penalty,
                        "presence_penalty": request.presence_penalty,
                        "frequency_penalty": request.frequency_penalty,
                    },
                    # Stop sequences (not yet supported by Parallax executor)
                    "stop": request.stop if request.stop else None,
                }
                logger.debug(f"📦 [{request_id}] Payload: {payload}")

                resp = await client.post(
                    PARALLAX_SERVICE_URL, json=payload, timeout=60.0
                )

                if resp.status_code != 200:
                    logger.error(
                        f"❌ [{request_id}] Parallax returned {resp.status_code}: {resp.text}"
                    )
                    raise HTTPException(
                        status_code=resp.status_code,
                        detail=f"Parallax Error: {resp.text}",
                    )

                # Parse OpenAI response format
                # Note: Parallax uses "messages" (plural) not "message" in the response
                # Fallback to standard "message" (singular) if they switch to OpenAI standard
                data = resp.json()
                choice = data["choices"][0]
                raw_content = (
                    choice.get("messages", {}).get("content")
                    or choice.get("message", {}).get("content")
                    or ""
                )

                # Clean response - remove <think>...</think> tags that some models include
                content = re.sub(
                    r"<think>.*?</think>", "", raw_content, flags=re.DOTALL
                ).strip()

                # If the entire response was just thinking, provide fallback
                if not content:
                    content = raw_content  # Return original if filtering left nothing

                # Extract usage metadata (token counts)
                usage = data.get("usage", {})

                elapsed = (datetime.now() - start_time).total_seconds()
                logger.info(
                    f"✅ [{request_id}] Received response from Parallax ({elapsed:.2f}s)"
                )
                logger.info(
                    f"📊 [{request_id}] Tokens - Prompt: {usage.get('prompt_tokens', 0)}, "
                    f"Completion: {usage.get('completion_tokens', 0)}, "
                    f"Total: {usage.get('total_tokens', 0)}"
                )
                logger.debug(f"📨 [{request_id}] Response preview: {content[:100]}...")

                # Return response with metadata for mobile app
                return {
                    "response": content,
                    # Metadata for display in mobile app
                    "metadata": {
                        "usage": {
                            "prompt_tokens": usage.get("prompt_tokens", 0),
                            "completion_tokens": usage.get("completion_tokens", 0),
                            "total_tokens": usage.get("total_tokens", 0),
                        },
                        "timing": {
                            "duration_ms": int(elapsed * 1000),
                            "duration_seconds": round(elapsed, 2),
                        },
                        "model": data.get("model", "default"),
                    },
                }

        except httpx.TimeoutException as e:
            logger.error(f"⏱️ [{request_id}] Parallax request timeout: {e}")
            raise HTTPException(
                status_code=504,
                detail="Parallax request timed out. The model might be processing a heavy request.",
            )
        except httpx.ConnectError as e:
            logger.error(f"🔌 [{request_id}] Cannot connect to Parallax: {e}")
            raise HTTPException(
                status_code=503,
                detail="Cannot connect to Parallax. Make sure it's running: parallax run",
            )
        except Exception as e:
            logger.error(f"❌ [{request_id}] Proxy error: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=f"Remote Service Error: {e}")


@app.post("/chat/stream", dependencies=[Depends(check_password)])
async def chat_stream_endpoint(request: ChatRequest):
    """
    Streaming chat endpoint that returns Server-Sent Events (SSE).
    
    Streams tokens as they're generated, including thinking content.
    Format: Each SSE event contains JSON with either:
    - {"type": "thinking", "content": "..."} - Model's reasoning (inside <think> tags)
    - {"type": "content", "content": "..."} - Final response content
    - {"type": "done", "metadata": {...}} - Stream complete with usage stats
    - {"type": "error", "message": "..."} - Error occurred
    """
    request_id = datetime.now().strftime("%Y%m%d%H%M%S%f")
    logger.info(f"🌊 [{request_id}] Streaming chat request: {request.prompt[:50]}...")

    if SERVER_MODE == "MOCK":
        async def mock_stream():
            # Simulate thinking
            thinking_lines = [
                "Let me analyze this question...",
                "Considering the context provided...",
                "Breaking down the key points...",
                "Formulating a comprehensive response...",
            ]
            for line in thinking_lines:
                yield f"data: {json.dumps({'type': 'thinking', 'content': line})}\n\n"
                await asyncio.sleep(0.3)
            
            # Simulate response
            response = f"[MOCK] Server received: '{request.prompt}'. This is a simulated streaming response."
            words = response.split()
            for word in words:
                yield f"data: {json.dumps({'type': 'content', 'content': word + ' '})}\n\n"
                await asyncio.sleep(0.1)
            
            yield f"data: {json.dumps({'type': 'done', 'metadata': {'prompt_tokens': 10, 'completion_tokens': len(words)}})}\n\n"
        
        return StreamingResponse(mock_stream(), media_type="text/event-stream")

    # PROXY mode - forward to Parallax with streaming
    async def stream_from_parallax():
        start_time = datetime.now()
        try:
            # Build messages array
            if request.messages:
                messages = list(request.messages)
                if request.system_prompt:
                    messages.insert(0, {"role": "system", "content": request.system_prompt})
            else:
                messages = []
                if request.system_prompt:
                    messages.append({"role": "system", "content": request.system_prompt})
                messages.append({"role": "user", "content": request.prompt})

            payload = {
                "model": request.model or "default",
                "messages": messages,
                "stream": True,  # Enable streaming
                "max_tokens": request.max_tokens,
                "sampling_params": {
                    "temperature": request.temperature,
                    "top_p": request.top_p,
                    "top_k": request.top_k,
                },
            }

            async with httpx.AsyncClient() as client:
                async with client.stream(
                    "POST",
                    PARALLAX_SERVICE_URL,
                    json=payload,
                    timeout=None,  # No timeout for streaming
                ) as response:
                    if response.status_code != 200:
                        error_text = await response.aread()
                        yield f"data: {json.dumps({'type': 'error', 'message': f'Parallax error: {error_text.decode()}'})}\n\n"
                        return

                    # Track state for parsing <think> tags
                    buffer = ""
                    in_thinking = False
                    thinking_started = False
                    prompt_tokens = 0
                    completion_tokens = 0

                    async for line in response.aiter_lines():
                        if not line.strip() or line.startswith(":"):
                            continue
                        
                        if line.startswith("data: "):
                            data_str = line[6:]
                            if data_str == "[DONE]":
                                break
                            
                            try:
                                data = json.loads(data_str)
                                
                                # Extract token from SSE chunk
                                # Parallax may use different formats, add fallbacks
                                choices = data.get("choices", [{}])
                                if choices:
                                    choice = choices[0]
                                    # Try delta (OpenAI streaming standard)
                                    delta = choice.get("delta", {})
                                    content = delta.get("content", "")
                                    # Fallback: try message/messages (non-standard)
                                    if not content:
                                        content = choice.get("message", {}).get("content", "")
                                    if not content:
                                        content = choice.get("messages", {}).get("content", "")
                                    # Fallback: try text field (some APIs use this)
                                    if not content:
                                        content = choice.get("text", "")
                                else:
                                    content = ""
                                
                                # Update token counts
                                usage = data.get("usage", {})
                                if usage.get("prompt_tokens"):
                                    prompt_tokens = usage["prompt_tokens"]
                                if usage.get("completion_tokens"):
                                    completion_tokens = usage["completion_tokens"]
                                
                                if content:
                                    buffer += content
                                    
                                    # Check for <think> tag start
                                    if "<think>" in buffer and not in_thinking:
                                        in_thinking = True
                                        thinking_started = True
                                        # Remove the tag from buffer
                                        buffer = buffer.replace("<think>", "")
                                    
                                    # Check for </think> tag end
                                    if "</think>" in buffer and in_thinking:
                                        in_thinking = False
                                        # Send remaining thinking content
                                        think_content = buffer.split("</think>")[0]
                                        if think_content.strip():
                                            yield f"data: {json.dumps({'type': 'thinking', 'content': think_content})}\n\n"
                                        # Keep content after </think>
                                        buffer = buffer.split("</think>", 1)[1] if "</think>" in buffer else ""
                                        continue
                                    
                                    # Stream content based on state
                                    if in_thinking:
                                        # Send thinking content in chunks (by newline or every ~50 chars)
                                        if "\n" in buffer or len(buffer) > 50:
                                            yield f"data: {json.dumps({'type': 'thinking', 'content': buffer})}\n\n"
                                            buffer = ""
                                    else:
                                        # Stream regular content immediately
                                        if buffer:
                                            yield f"data: {json.dumps({'type': 'content', 'content': buffer})}\n\n"
                                            buffer = ""
                                
                            except json.JSONDecodeError:
                                continue

                    # Flush any remaining buffer
                    if buffer.strip():
                        msg_type = "thinking" if in_thinking else "content"
                        yield f"data: {json.dumps({'type': msg_type, 'content': buffer})}\n\n"

                    elapsed = (datetime.now() - start_time).total_seconds()
                    logger.info(f"✅ [{request_id}] Stream completed ({elapsed:.2f}s)")
                    
                    yield f"data: {json.dumps({'type': 'done', 'metadata': {'prompt_tokens': prompt_tokens, 'completion_tokens': completion_tokens, 'duration_seconds': round(elapsed, 2)}})}\n\n"

        except httpx.ConnectError as e:
            logger.error(f"🔌 [{request_id}] Cannot connect to Parallax: {e}")
            yield f"data: {json.dumps({'type': 'error', 'message': 'Cannot connect to Parallax. Make sure it is running.'})}\n\n"
        except Exception as e:
            logger.error(f"❌ [{request_id}] Stream error: {e}", exc_info=True)
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return StreamingResponse(
        stream_from_parallax(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering
        },
    )


@app.post("/vision", dependencies=[Depends(check_password)])
async def vision_endpoint(image: UploadFile = File(...), prompt: str = Form(...)):
    request_id = datetime.now().strftime("%Y%m%d%H%M%S%f")
    logger.info(f"📸 [{request_id}] Vision request: {prompt[:50]}...")

    if SERVER_MODE == "MOCK":
        logger.info(f"📤 [{request_id}] Returning MOCK vision response")
        return {
            "response": f"[MOCK] Vision Analysis: I see a simulated image. Prompt: {prompt}"
        }

    # TODO: Implement Vision Proxy when Parallax supports Multi-Modal API
    logger.warning(f"⚠️ [{request_id}] Vision proxy not yet implemented")
    return {"response": "[PROXY] Vision not yet implemented in Parallax API wrapper."}


# =============================================================================
# PARALLAX WEB UI PROXY
# =============================================================================
# These routes proxy the Parallax Web UI (served on port 3001) through this server.
# Access the UI at: http://<server>:8000/ui/
# This allows remote access to the Parallax dashboard via ngrok tunnel.
# =============================================================================


@app.get("/ui", dependencies=[Depends(check_password)])
async def ui_redirect():
    """Redirect /ui to /ui/ for proper routing."""
    return HTMLResponse(
        content='<html><head><meta http-equiv="refresh" content="0;url=/ui/"></head></html>',
        status_code=200,
    )


@app.get("/ui/", dependencies=[Depends(check_password)])
async def ui_index():
    """Serve the Parallax UI index page."""
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(f"{PARALLAX_UI_URL}/", timeout=10.0)
            
            # Rewrite asset paths to go through our proxy
            content = resp.text
            content = content.replace('href="/', 'href="/ui/')
            content = content.replace("href='/", "href='/ui/")
            content = content.replace('src="/', 'src="/ui/')
            content = content.replace("src='/", "src='/ui/")
            
            return HTMLResponse(content=content, status_code=resp.status_code)
    except Exception as e:
        logger.error(f"❌ UI proxy error: {e}")
        return HTMLResponse(
            content=f"<h1>Cannot connect to Parallax UI</h1><p>Error: {e}</p><p>Make sure Parallax is running on port 3001.</p>",
            status_code=503,
        )


@app.get("/ui/{path:path}", dependencies=[Depends(check_password)])
async def ui_proxy(path: str, request: Request):
    """Proxy all Parallax UI requests (assets, API calls, etc.)."""
    try:
        # Build the target URL
        target_url = f"{PARALLAX_UI_URL}/{path}"
        
        # Include query parameters
        if request.query_params:
            target_url += f"?{request.query_params}"

        async with httpx.AsyncClient() as client:
            resp = await client.get(target_url, timeout=30.0)
            
            # Get content type
            content_type = resp.headers.get("content-type", "application/octet-stream")
            
            # For HTML content, rewrite paths
            if "text/html" in content_type:
                content = resp.text
                content = content.replace('href="/', 'href="/ui/')
                content = content.replace("href='/", "href='/ui/")
                content = content.replace('src="/', 'src="/ui/')
                content = content.replace("src='/", "src='/ui/")
                return HTMLResponse(content=content, status_code=resp.status_code)
            
            # For other content, pass through as-is
            return Response(
                content=resp.content,
                status_code=resp.status_code,
                media_type=content_type,
            )
    except Exception as e:
        logger.error(f"❌ UI proxy error for {path}: {e}")
        return Response(content=str(e), status_code=503)


@app.api_route("/ui-api/{path:path}", methods=["GET", "POST", "PUT", "DELETE"], dependencies=[Depends(check_password)])
async def ui_api_proxy(path: str, request: Request):
    """Proxy API calls from the Parallax UI."""
    try:
        target_url = f"{PARALLAX_UI_URL}/{path}"
        
        # Include query parameters
        if request.query_params:
            target_url += f"?{request.query_params}"

        async with httpx.AsyncClient() as client:
            # Get request body if present
            body = await request.body()
            
            # Forward the request with same method
            resp = await client.request(
                method=request.method,
                url=target_url,
                content=body if body else None,
                headers={
                    k: v for k, v in request.headers.items()
                    if k.lower() not in ["host", "content-length"]
                },
                timeout=60.0,
            )
            
            content_type = resp.headers.get("content-type", "application/json")
            
            # Handle SSE streams (like /cluster/status)
            if "text/event-stream" in content_type or "application/x-ndjson" in content_type:
                async def stream_response():
                    async with httpx.AsyncClient() as stream_client:
                        async with stream_client.stream(
                            method=request.method,
                            url=target_url,
                            content=body if body else None,
                            timeout=None,
                        ) as stream_resp:
                            async for chunk in stream_resp.aiter_bytes():
                                yield chunk

                return StreamingResponse(
                    stream_response(),
                    media_type=content_type,
                )
            
            return Response(
                content=resp.content,
                status_code=resp.status_code,
                media_type=content_type,
            )
    except Exception as e:
        logger.error(f"❌ UI API proxy error for {path}: {e}")
        return Response(content=str(e), status_code=503)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
