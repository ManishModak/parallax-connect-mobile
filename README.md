# Parallax Connect

A mobile-first AI interface that connects to your self-hosted Parallax GPU server. Turn any Parallax-enabled machine into a private AI cloud accessible from anywhere.

## Overview

Parallax Connect decouples the AI interface (mobile app) from the compute (GPU server), allowing you to:
- Access your home GPU from anywhere via secure tunnel
- Share one GPU across multiple family members/devices
- Switch seamlessly between cloud and local connections
- Keep all data private on your own hardware

## Project Structure

```
parallax-connect/
├── app/                    # Flutter mobile application
├── server/                 # Python FastAPI server (modular)
│   ├── apis/               # API route handlers
│   │   ├── chat.py         # /chat, /chat/stream endpoints
│   │   ├── health.py       # /, /healthz, /status endpoints
│   │   ├── models.py       # /models, /info endpoints
│   │   └── ui_proxy.py     # Parallax Web UI proxy
│   ├── auth/               # Authentication
│   │   └── password.py     # Password protection
│   ├── models/             # Pydantic request/response models
│   ├── services/           # External service clients
│   │   └── parallax.py     # Parallax API client
│   ├── utils/              # Utilities (network, QR codes)
│   ├── app.py              # FastAPI application factory
│   ├── config.py           # Configuration constants
│   ├── logging_setup.py    # Logging configuration
│   └── startup.py          # Server startup & ngrok setup
├── helper-docs/            # Setup guides and references
├── assets/                 # Project assets (logos)
├── run_server.py           # Server entry point
├── requirements.txt        # Python dependencies
├── SERVER_SETUP.md         # Server installation guide
└── SERVER_USAGE_GUIDE.md   # API documentation
```

## Quick Start

### 1. Start the Server

```bash
# Install dependencies
pip install -r requirements.txt

# Run the server
python run_server.py
```

### 2. Connect the App

Scan the QR code displayed in the terminal with the Parallax Connect mobile app.

## Connection Modes

| Mode | Use Case | Requirements |
|------|----------|--------------|
| Cloud (Ngrok) | Access from anywhere | Ngrok account (free) |
| Local | Same Wi-Fi, lowest latency | None |

Both modes are active simultaneously when the server runs.

## Key Features

- Real-time streaming chat with thinking visualization
- Multi-turn conversation support
- Password protection (optional)
- Remote Parallax Web UI access
- Automatic QR code generation for easy connection

## Documentation

- [Server Setup Guide](SERVER_SETUP.md) - Installation and configuration
- [API Usage Guide](SERVER_USAGE_GUIDE.md) - API reference and Flutter integration
- [Helper Docs](helper-docs/) - Platform-specific setup guides

## Tech Stack

- Server: Python, FastAPI, httpx, pyngrok
- App: Flutter, Dart
- AI Backend: Parallax (local GPU inference)

## License

MIT
