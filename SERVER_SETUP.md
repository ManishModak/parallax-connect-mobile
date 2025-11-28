# Server Setup Guide

Complete guide to setting up the Parallax Connect server.

## Prerequisites

- Python 3.8 or higher
- Parallax installed and running on your GPU machine
- Git (optional, for cloning)

## Installation

### 1. Get the Code

```bash
git clone https://github.com/ManishModak/parallax-connect.git
cd parallax-connect
```

Or download and extract the ZIP.

### 2. Create Virtual Environment (Recommended)

```bash
# Windows
python -m venv .venv
.venv\Scripts\activate

# macOS/Linux
python3 -m venv .venv
source .venv/bin/activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

## Configuration

### Server Settings

Edit `server/config.py` to customize:

```python
# Server mode: "PROXY" (production) or "MOCK" (testing)
SERVER_MODE = "PROXY"

# Parallax endpoints (default ports)
PARALLAX_SERVICE_URL = "http://localhost:3001/v1/chat/completions"
PARALLAX_UI_URL = "http://localhost:3001"
```

### Parallax Setup

Ensure Parallax is running before starting the server:

```bash
# Start Parallax scheduler
parallax run
```

The server connects to Parallax on port 3001 by default.

## Running the Server

```bash
python run_server.py
```

On startup, the server will:
1. Test connection to Parallax
2. Prompt for optional password protection
3. Start ngrok tunnel (if configured)
4. Display QR codes for connection

## Connection Modes

### Cloud Mode (Ngrok)

Access your server from anywhere over the internet.

#### Setup

1. Create free account at [ngrok.com](https://dashboard.ngrok.com)
2. Copy your authtoken from the dashboard
3. Configure ngrok:

```bash
ngrok config add-authtoken YOUR_TOKEN_HERE
```

4. Start the server - cloud URL will appear automatically

#### Limits

- Free tier: 1GB bandwidth/month
- Sufficient for personal/family use

### Local Mode

Direct connection over your local network. Always available.

#### Requirements

- Phone and server on the same Wi-Fi network
- Or use phone hotspot for both devices

#### Advantages

- Zero latency overhead
- No bandwidth limits
- Works offline

## Password Protection

When the server starts, you'll be prompted:

```
🔒 Set a password for this server? (y/n):
```

If enabled:
- All API requests require `x-password` header
- Mobile app will prompt for password on first connect

## Server Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/` | GET | Yes | Server status |
| `/healthz` | GET | No | Health check |
| `/status` | GET | Yes | Detailed status with Parallax connectivity |
| `/models` | GET | Yes | Available models |
| `/info` | GET | Yes | Server capabilities |
| `/chat` | POST | Yes | Send chat message |
| `/chat/stream` | POST | Yes | Streaming chat (SSE) |
| `/vision` | POST | Yes | Vision analysis (placeholder) |
| `/ui/` | GET | Yes | Parallax Web UI proxy |

## Logs

Server logs are stored in `applogs/` directory:
- Automatic rotation (5MB max per file)
- Keeps last 5 log files
- Includes timestamps and request IDs

## Troubleshooting

### Cannot connect to Parallax

```
⚠️ Cannot reach Parallax: Connection refused
```

Solution: Ensure Parallax is running with `parallax run`

### Ngrok not starting

```
⚠️ Ngrok Auth Token not found
```

Solution: Run `ngrok config add-authtoken YOUR_TOKEN`

### Connection refused on mobile

1. Check firewall allows port 8000
2. Verify both devices on same network (local mode)
3. Try using phone hotspot

### Port already in use

```bash
# Find process using port 8000
netstat -ano | findstr :8000

# Kill the process (Windows)
taskkill /PID <PID> /F
```

## Project Structure

```
server/
├── apis/
│   ├── chat.py          # Chat endpoints
│   ├── health.py        # Health/status endpoints
│   ├── models.py        # Model info endpoints
│   └── ui_proxy.py      # Web UI proxy
├── auth/
│   └── password.py      # Password authentication
├── models/
│   └── chat.py          # Request/response models
├── services/
│   └── parallax.py      # Parallax API client
├── utils/
│   └── network.py       # Network utilities
├── app.py               # FastAPI app factory
├── config.py            # Configuration
├── logging_setup.py     # Logging setup
└── startup.py           # Startup logic
```

## Next Steps

1. Start the server: `python run_server.py`
2. Open Parallax Connect app on your phone
3. Scan the QR code to connect
4. Start chatting with your local AI!
