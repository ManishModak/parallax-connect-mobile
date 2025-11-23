from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from pydantic import BaseModel
import uvicorn
import httpx

# --- CONFIGURATION ---
# Options: "MOCK", "PROXY"
# - MOCK: Returns dummy data (for UI Dev).
# - PROXY: Forwards requests to running Parallax Service (localhost:3002).
SERVER_MODE = "MOCK"

# Parallax Service Endpoint (OpenAI Compatible)
PARALLAX_SERVICE_URL = "http://localhost:3002/v1/chat/completions"

app = FastAPI()

print(f"🚀 Server Starting... MODE: {SERVER_MODE}")


@app.get("/")
def home():
    return {"status": "online", "mode": SERVER_MODE, "device": "Server Node"}


class ChatRequest(BaseModel):
    prompt: str


@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    print(f"📝 Text Request: {request.prompt}")

    if SERVER_MODE == "MOCK":
        return {
            "response": f"[MOCK] Server received: '{request.prompt}'. \n\nThis is a simulated response."
        }

    elif SERVER_MODE == "PROXY":
        # Forward to Parallax Service (OpenAI API)
        try:
            async with httpx.AsyncClient() as client:
                # Construct OpenAI-compatible payload
                payload = {
                    "model": "default",  # Or specific model name if needed
                    "messages": [{"role": "user", "content": request.prompt}],
                    "stream": False,
                }

                resp = await client.post(
                    PARALLAX_SERVICE_URL, json=payload, timeout=60.0
                )

                if resp.status_code != 200:
                    raise HTTPException(
                        status_code=resp.status_code,
                        detail=f"Parallax Error: {resp.text}",
                    )

                # Parse OpenAI response format
                data = resp.json()
                content = data["choices"][0]["message"]["content"]
                return {"response": content}

        except Exception as e:
            print(f"❌ Proxy Error: {e}")
            raise HTTPException(status_code=500, detail=f"Remote Service Error: {e}")


@app.post("/vision")
async def vision_endpoint(image: UploadFile = File(...), prompt: str = Form(...)):
    print(f"📸 Vision Request: {prompt}")

    if SERVER_MODE == "MOCK":
        return {
            "response": f"[MOCK] Vision Analysis: I see a simulated image. Prompt: {prompt}"
        }

    # TODO: Implement Vision Proxy when Parallax supports Multi-Modal API
    return {"response": "[PROXY] Vision not yet implemented in Parallax API wrapper."}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
