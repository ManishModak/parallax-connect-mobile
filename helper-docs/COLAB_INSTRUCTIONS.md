# 🚀 Google Colab Setup Instructions

Use these steps to run your backend on a free Google Colab T4 GPU. This creates a public URL that your Flutter app can talk to.

## Step 1: Open Google Colab

Go to [colab.research.google.com](https://colab.research.google.com/) and create a **New Notebook**.

## Step 2: Copy & Paste These Cells

### Cell 1: Install Dependencies

```python
!nvidia-smi # Check GPU
!git clone https://github.com/GradientHQ/parallax.git
%cd parallax
!pip install -e '.[gpu]' --extra-index-url https://download.pytorch.org/whl/cu124
!pip install fastapi uvicorn python-multipart pyngrok nest_asyncio httpx
```

### Cell 2: Start Parallax Service (Background)

This starts the Parallax Scheduler and Node in the background.

```python
# Start Parallax in background
get_ipython().system_raw('nohup parallax run --host 0.0.0.0 > parallax.log 2>&1 &')
print("⏳ Parallax Service Starting... waiting 20s...")
import time; time.sleep(20)
print("✅ Parallax Service (should be) Ready on Port 3001/3002")
```

### Cell 3: Configure Ngrok

**Crucial:** You need an Ngrok account (free).

1. Go to [dashboard.ngrok.com](https://dashboard.ngrok.com).
2. Copy your **Authtoken**.
3. Paste it below.

```python
from pyngrok import ngrok

# REPLACE THIS WITH YOUR TOKEN
NGROK_AUTH_TOKEN = "YOUR_NGROK_TOKEN_HERE" 

ngrok.set_auth_token(NGROK_AUTH_TOKEN)
```

### Cell 4: Create Server Code

This writes the `server.py` file directly into the Colab instance.

```python
%%writefile server.py
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from pydantic import BaseModel
import uvicorn
import httpx
import os

# --- TOGGLE THIS FOR REAL TESTING ---
SERVER_MODE = "MOCK" 
# Change to "PROXY" to use the real Parallax Service!

# Parallax Service Endpoint (OpenAI Compatible)
PARALLAX_SERVICE_URL = "http://localhost:3002/v1/chat/completions"

app = FastAPI()

@app.get("/")
def home():
    return {"status": "online", "mode": SERVER_MODE}

class ChatRequest(BaseModel):
    prompt: str

@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    if SERVER_MODE == "MOCK":
        return {"response": f"[MOCK] Colab received: '{request.prompt}'"}
    
    # PROXY MODE: Forward to Parallax
    try:
        async with httpx.AsyncClient() as client:
            payload = {
                "model": "default",
                "messages": [{"role": "user", "content": request.prompt}],
                "stream": False
            }
            resp = await client.post(PARALLAX_SERVICE_URL, json=payload, timeout=60.0)
            if resp.status_code != 200:
                return {"response": f"Error: {resp.text}"}
            data = resp.json()
            return {"response": data["choices"][0]["message"]["content"]}
    except Exception as e:
        return {"response": f"Proxy Error: {e}"}

@app.post("/vision")
async def vision_endpoint(image: UploadFile = File(...), prompt: str = Form(...)):
    if SERVER_MODE == "MOCK":
        return {"response": f"[MOCK] Vision: {prompt}"}
    return {"response": "Vision Proxy not implemented yet."}
```

### Cell 5: Run Server & Get URL

```python
import nest_asyncio
import uvicorn
from pyngrok import ngrok

# Allow uvicorn to run in Jupyter
nest_asyncio.apply()

# Close old tunnels if any
ngrok.kill()

# Open Tunnel
public_url = ngrok.connect(8000).public_url
print(f"✅ YOUR FLUTTER API URL IS: {public_url}")
print("Copy this URL into your Flutter App!")

# Run Server
uvicorn.run("server:app", host="0.0.0.0", port=8000)
```

## Step 3: Test It

1. Run all cells.
2. Copy the `https://....ngrok-free.app` URL.
3. **Test in Browser:** Visit `YOUR_URL/docs` to see the Swagger UI and test endpoints manually.
4. **Test in Flutter:** Use this URL for your API calls.

## Switching to Real Mode

1. Change `SERVER_MODE = "PROXY"` in Cell 4.
2. Re-run Cell 4 and Cell 5.
