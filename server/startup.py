"""Server startup logic and event handlers."""

import httpx
from pyngrok import ngrok

from .auth import setup_password
from .config import SERVER_MODE, PARALLAX_SERVICE_URL, TIMEOUT_FAST
from .utils import get_local_ip, print_qr
from .logging_setup import get_logger

logger = get_logger(__name__)


async def on_startup():
    """Server startup event handler."""
    from .config import DEBUG_MODE

    logger.info(
        "🚀 Server Starting...",
        extra={
            "extra_data": {
                "event": "startup",
                "mode": SERVER_MODE,
                "parallax_url": PARALLAX_SERVICE_URL,
                "debug_mode": DEBUG_MODE,
            }
        },
    )

    # Test Parallax connection if in PROXY mode
    if SERVER_MODE == "PROXY":
        await _test_parallax_connection()

    # Setup password protection
    setup_password()

    # Display connection info
    _display_connection_info()


async def _test_parallax_connection():
    """Test connection to Parallax service."""
    logger.info(f"Testing connection to Parallax at {PARALLAX_SERVICE_URL}...")
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                "http://localhost:3001/model/list", timeout=TIMEOUT_FAST
            )
            if resp.status_code == 200:
                logger.info(
                    "✅ Parallax connection successful",
                    extra={"extra_data": {"parallax_status": "connected"}},
                )
            else:
                logger.warning(
                    f"⚠️ Parallax returned status {resp.status_code}",
                    extra={
                        "extra_data": {
                            "parallax_status": "error",
                            "status_code": resp.status_code,
                        }
                    },
                )
    except Exception as e:
        logger.warning(
            f"⚠️ Cannot reach Parallax: {e}",
            extra={"extra_data": {"parallax_status": "unreachable", "error": str(e)}},
        )
        logger.warning("Make sure Parallax is running: parallax run")


def _display_connection_info():
    """Display connection URLs and QR codes."""
    local_ip = get_local_ip()
    local_url = f"http://{local_ip}:8000"

    # Try to start Ngrok tunnel
    public_url = _start_ngrok_tunnel()

    # Display connection info
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


def _start_ngrok_tunnel() -> str | None:
    """Start ngrok tunnel and return public URL."""
    try:
        http_tunnel = ngrok.connect(8000)
        return http_tunnel.public_url
    except Exception as e:
        error_msg = str(e).lower()
        if "authtoken" in error_msg or "authentication" in error_msg:
            print("⚠️ Ngrok Auth Token not found. Skipping Cloud Tunnel.")
            print("   Run: ngrok config add-authtoken <TOKEN> to enable Cloud Mode.")
        else:
            print(f"⚠️ Could not start Ngrok: {e}")
        return None
