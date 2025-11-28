# Parallax Connect – Master Reference

> Single source of truth for architecture, API flow, integration logic, and Parallax source insights. Replaces `docs/API_FLOW.md`, `docs/PARALLAX_ARCHITECTURE.md`, `docs/PARALLAX_API_REFERENCE.md`, and `docs/PARALLAX_ADVANCED_FEATURES.md`.

---

## Table of Contents
1. [System Architecture](#system-architecture)
2. [Parallax Source Code Insights](#parallax-source-code-insights)
3. [API Communication Flow](#api-communication-flow)
4. [Parallax Integration Details](#parallax-integration-details)
5. [Chat Continuation (Multi-Turn)](#chat-continuation-multi-turn)
6. [Configuration & Settings](#configuration--settings)
7. [Error Handling](#error-handling)
8. [Advanced Features & Sampling](#advanced-features--sampling)
9. [Testing & Debugging](#testing--debugging)
10. [Quick Reference Tables](#quick-reference-tables)

---

## System Architecture

```
App (Flutter, full history)
    ↓ HTTP(S)
server.py (FastAPI proxy, port 8000)
    ↓ HTTP
Parallax Scheduler (FastAPI, port 3001)
    ↔ Node Workers (port 3000, ZeroMQ ↔ Executor)
```

**Component responsibilities**
- **Flutter App**
  - `app/lib/src/features/chat/data/chat_repository.dart` (lines 1-116) – networking + auth header
  - `app/lib/src/features/chat/presentation/chat_controller.dart` (lines 1-255) – chat state, history persistence
- **Proxy Server**
  - `server.py` (lines 1-447) – password gating, /chat proxy, /vision placeholder, ngrok setup
- **Parallax Scheduler**
  - `parallax-main-repo/parallax/src/backend/main.py` – exposes `/v1/chat/completions`, `/model/list`, `/cluster/status`, etc.
- **Node Worker / Executor**
  - `parallax-main-repo/parallax/src/parallax/server/http_server.py` – HTTP layer
  - `parallax-main-repo/parallax/src/parallax/server/executor.py` – model execution, sampling params parsing

**Ports**
- Mobile app: N/A (client)
- `server.py`: 8000 (local & ngrok)
- Parallax Scheduler: 3001
- Parallax Node Worker: 3000
- Standalone Chat UI: 3002

---

## Parallax Source Code Insights

| File | Purpose | Key Takeaways |
| --- | --- | --- |
| `parallax/src/backend/main.py` | Scheduler FastAPI app | No `/health`; use `/model/list` for availability checks |
| `parallax/src/backend/server/request_handler.py` | Forwards chat requests with retry/backoff | Confirms `/v1/chat/completions` is OpenAI-compatible |
| `parallax/src/parallax/server/executor.py` lines 867-878 | Parses incoming sampling params | Only `temperature`, `top_k`, `top_p` handled today |
| `parallax/src/parallax/server/sampling/sampling_params.py` | Full SamplingParams definition | Contains placeholders for repetition/presence/frequency penalties, stop sequences, JSON schema |
| `parallax/src/parallax/p2p/message_util.py` + `proto/forward.proto` | Serialization between scheduler ↔ executor | All sampling params exist in protobuf even if executor ignores them |
| `parallax/src/frontend/src/services/chat.tsx` | Web UI client | Shows correct payload structure with `sampling_params` nested object |

**Implications for our proxy**
- Nest sampling params under `sampling_params` (`server.py` lines 341-360).
- Pass unsupported params for forward compatibility even though executor ignores them.
- Health/status checks should hit `/model/list` (`server.py` lines 98-110, 270-285).
- Streaming support is available via SSE if we add `/chat/stream`.

---

## API Communication Flow

1. **App → server.py** (`chat_repository.dart` lines 45-90)
   - `POST {baseUrl}/chat` with `prompt`, optional `system_prompt`, and `messages` (history).
   - `x-password` header if password set.
2. **server.py → Parallax** (`server.py` lines 309-366)
   - Builds OpenAI-compatible payload:
     ```json
     {
       "model": "default",
       "messages": [...],
       "stream": false,
       "max_tokens": 512,
       "sampling_params": { ... },
       "stop": null
     }
     ```
3. **Parallax Response → server.py** (`server.py` lines 355-411)
   - Extracts `choices[0].message.content`, attaches usage & timing metadata.
4. **server.py → App**
   - Returns `{ "response": "...", "metadata": { usage, timing, model } }`.

Mock vs Proxy Mode (config at `server.py` line 33):
- **MOCK**: returns simulated response (lines 296-300).
- **PROXY**: forwards to Parallax (lines 304-411).

Authenticate endpoints via `check_password` (`server.py` lines 66-70). `/healthz` stays public.

---

## Parallax Integration Details

| Endpoint | Method | Description | File |
| --- | --- | --- | --- |
| `/v1/chat/completions` | POST | Main chat API | `backend/main.py`, `request_handler.py` |
| `/cluster/status` | GET (SSE) | Cluster health stream | `backend/main.py` |
| `/model/list` | GET | Available models, used for health | `backend/main.py` |
| `/scheduler/init` | POST | Initialize cluster | `backend/main.py` |
| `/node/join/command` | GET | CLI join command | `backend/main.py` |

**Payload requirements (from Parallax frontend & executor)**
- `messages` array required.
- `sampling_params` must be nested.
- `stream` field accepted (`false` today).
- `rid` assigned internally; server.py auto-generates `request_id`.

---

## Chat Continuation (Multi-Turn)

**Flow**  
`ChatController.sendMessage` → builds `history` slice (`chat_controller.dart` lines 169-178).  
`ChatRepository.generateText` → converts history to OpenAI `messages` (`chat_repository.dart` lines 65-77).  
`server.py` → uses provided history or falls back to single prompt mode (`server.py` lines 321-339).

**History format**
```json
[
  {"role": "system", "content": "..."},
  {"role": "user", "content": "..."},
  {"role": "assistant", "content": "..."}
]
```

**Token considerations**
- Keep only last N exchanges (recommend 10-20) to avoid context overflow.
- Future enhancement: summarise or trim old context.

---

## Configuration & Settings

| Setting | Location | Notes |
| --- | --- | --- |
| Server Mode | `SERVER_MODE` (line 33) | `MOCK` vs `PROXY` |
| Password | Prompted on startup (`server.py` lines 44-63) | Stored in-memory only |
| Ngrok | `startup_event` (lines 94-151) | Optional cloud tunnel |
| Base URL (app) | `ConfigStorage` | Determines requests to local vs ngrok |
| Password header (app) | `_buildPasswordHeader` (`chat_repository.dart` lines 14-21) |

---

## Error Handling

**Mobile app**
- Dio errors logged via `logger.e` (`chat_repository.dart` lines 86-89).
- Connectivity guard in `ChatController` (`chat_controller.dart` lines 148-157).

**server.py**
- 503: Parallax unreachable (`server.py` lines 396-401).
- 504: Parallax timeout (`server.py` lines 390-395).
- 500: Catch-all proxy errors (`server.py` lines 402-404).
- 401: Invalid password (`check_password`).

**Common troubleshooting**
- Verify README curl commands (see [Testing](#testing--debugging)).
- Check server logs: request IDs logged at INFO level (`server.py` lines 301-393).

---

## Advanced Features & Sampling

**ChatRequest model** (`server.py` lines 165-268)
- Supported: `max_tokens`, `temperature`, `top_p`, `top_k`.
- Not yet supported (executor ignores): `repetition_penalty`, `presence_penalty`, `frequency_penalty`, `stop`.

**Executor parsing** (`parallax/server/executor.py` lines 867-878)
```python
raw_sampling_params = raw_request.get("sampling_params")
sampling_params = SamplingParams()
if "temperature" in raw_sampling_params:
    sampling_params.temperature = raw_sampling_params["temperature"]
# top_k, top_p handled similarly; other params TODO
```

**SamplingParams class** (`sampling_params.py`)
- Defines full schema (min_p, stop tokens, ignore_eos, json_schema, penalties).
- Mirrors protobuf schema (`forward.proto` lines 40-54).

**Future enhancements (🎯)**
- Add `/chat/stream` endpoint to proxy SSE tokens.
- Proxy `/cluster/status` & `/model/list` for mobile monitoring UI.
- Surface token usage/timing already returned (`server.py` metadata block).

---

## Testing & Debugging

| Layer | Command |
| --- | --- |
| Parallax scheduler | `curl http://localhost:3001/v1/chat/completions -H "Content-Type: application/json" -d '{"messages":[{"role":"user","content":"test"}],"stream":false}'` |
| server.py proxy | `curl -X POST http://localhost:8000/chat -H "Content-Type: application/json" -H "x-password: YOUR_PASSWORD" -d '{"prompt":"test"}'` |
| Mobile app | Use UI; monitor Dio logs and `server.py` console for request IDs |

**Logging**
- Configured at top of `server.py` (lines 21-27).
- Each request logs:
  - Received prompt snippet (`logger.info`).
  - Forwarding status.
  - Response timing + token usage (lines 362-369).

---

## Quick Reference Tables

### Endpoints & Auth

| Endpoint | Auth? | Description |
| --- | --- | --- |
| `GET /healthz` | No | Public health check |
| `GET /` | Yes | Basic server info |
| `GET /status` | Yes | Includes Parallax connectivity |
| `POST /chat` | Yes | Chat proxy/mock |
| `POST /vision` | Yes | Placeholder (returns TODO) |

### Server Modes

| Mode | Behavior | Use Case |
| --- | --- | --- |
| `MOCK` | Returns simulated message | UI dev, offline demo |
| `PROXY` | Proxies to Parallax scheduler | Production / real responses |

### Sampling Parameters (current status)

| Parameter | Supported in executor? | Notes |
| --- | --- | --- |
| `temperature` | ✅ | Scalar float |
| `top_p` | ✅ | Nucleus sampling |
| `top_k` | ✅ | `-1` disables |
| `max_tokens` | ✅ | Provided at root |
| `repetition_penalty` | ❌ | Defined but ignored |
| `presence_penalty` | ❌ | Defined but ignored |
| `frequency_penalty` | ❌ | Defined but ignored |
| `stop` | ❌ | Provided for future |

### Status Codes Returned by server.py

| Code | Source | Meaning |
| --- | --- | --- |
| 200 | Success | Chat completion delivered |
| 401 | FastAPI | Missing/invalid password |
| 503 | httpx.ConnectError | Parallax offline |
| 504 | httpx.TimeoutException | Long-running request |
| 500 | Generic exception | Unexpected proxy error |

---

## Sunset Notice
The following files are superseded by this document and can be removed after review:
- `docs/API_FLOW.md`
- `docs/PARALLAX_ARCHITECTURE.md`
- `docs/PARALLAX_API_REFERENCE.md`
- `docs/PARALLAX_ADVANCED_FEATURES.md`
