# Developer API Guide

> **Note for App Users:** You do not need to read this guide to use the app. This document is for developers who want to build their own tools or integrate with the Parallax Connect server.

---

## 🔌 API Overview

The Parallax Connect server provides a REST API to interact with the Parallax AI backend. It acts as a bridge, handling authentication, logging, and remote access.

### Base URLs

- **Local**: `http://YOUR_COMPUTER_IP:8000`
- **Cloud**: `https://RANDOM_ID.ngrok.io`

### Authentication

If you set a password during startup, you must include it in the headers of every request:

```http
x-password: YOUR_PASSWORD
```

---

## 💬 Chat Endpoints

### 1. Send a Message (Standard)

Send a prompt and get a complete response.

**POST** `/chat`

**Request Body:**

```json
{
  "prompt": "Explain quantum physics like I'm 5",
  "model": "llama-3-8b",
  "temperature": 0.7
}
```

**Response:**

```json
{
  "response": "Imagine you have a magic ball...",
  "metadata": {
    "usage": { "total_tokens": 150 },
    "timing": { "duration_seconds": 2.5 }
  }
}
```

### 2. Stream a Message (Real-time)

Receive the response word-by-word, just like ChatGPT.

**POST** `/chat/stream`

**Response (Server-Sent Events):**

```
data: {"type": "thinking", "content": "Analyzing request..."}
data: {"type": "content", "content": "Imagine "}
data: {"type": "content", "content": "you "}
data: {"type": "content", "content": "have "}
...
data: {"type": "done", "metadata": {...}}
```

---

## ℹ️ System Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/status` | GET | Check if Parallax is connected and ready. |
| `/models` | GET | List all available AI models. |
| `/healthz` | GET | Simple health check (returns "ok"). |

---

## 🛠️ Integration Examples

### Python Example

```python
import requests

url = "http://localhost:8000/chat"
headers = {"x-password": "mypassword"}
data = {
    "prompt": "Hello AI!",
    "temperature": 0.7
}

response = requests.post(url, json=data, headers=headers)
print(response.json()["response"])
```

### cURL Example

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello!"}'
```
