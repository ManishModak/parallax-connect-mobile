"""Entry point for Parallax Connect Server.

To run the server:
    python run_server.py

Project structure:
    server/
    ├── app.py           # FastAPI app factory
    ├── config.py        # Configuration constants
    ├── logging_setup.py # Logging configuration
    ├── startup.py       # Startup events & ngrok
    ├── apis/            # API route handlers
    ├── auth/            # Authentication
    ├── models/          # Pydantic models
    ├── services/        # External service clients
    └── utils/           # Utility functions
"""

import uvicorn

from server.app import app

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
