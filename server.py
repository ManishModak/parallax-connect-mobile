import getpass
import socket
import uvicorn
import httpx
import qrcode
import logging
from datetime import datetime
from fastapi import (
    Depends,
    FastAPI,
    File,
    Form,
    Header,
    HTTPException,
    UploadFile,
)
from pydantic import BaseModel
from pyngrok import ngrok
from typing import List, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
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
    """Prompt user for optional password protection."""
    global PASSWORD

    try:
        choice = input("\n🔒 Set a password for this server? (y/n): ").strip().lower()
    except EOFError:
        choice = "n"

    if choice == "y":
        password = getpass.getpass("Enter password: ").strip()
        if password:
            PASSWORD = password
            print("✅ Password protection enabled\n")
        else:
            PASSWORD = None
            print("⚠️  Empty password. Server remains open.\n")
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

    # === CONVERSATION HISTORY (FOR MULTI-TURN CHAT) ===
    messages: Optional[List[dict]] = None
    """
    Conversation history for multi-turn chat continuation.
    Format: [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]
    - If provided, enables context-aware responses using previous messages
    - If None/empty, falls back to single prompt mode (backwards compatible)
    """

    # === BASIC PARAMETERS (SUPPORTED) ===
    max_tokens: int = 512
    """
    Maximum number of tokens (words/pieces) to generate.
    STATUS: SUPPORTED by Parallax
    - Default: 512
    - Range: 1 to model's max (usually 2048-4096)
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
                    "model": "default",
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
                data = resp.json()
                content = data["choices"][0]["messages"]["content"]

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


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
