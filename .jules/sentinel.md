## 2024-05-24 - Information Leakage in Error Handling
**Vulnerability:** The `handle_service_error` function in `server/utils/error_handler.py` was exposing raw exception messages to API clients in the `detail` field. This could leak sensitive internal information such as file paths, database connection strings, or internal IP addresses if an exception occurred.
**Learning:** Default error handlers often prioritize developer convenience (showing the full error) over security. Explicit checks for `DEBUG_MODE` or environment type are crucial to sanitize errors in production.
**Prevention:** Always wrap error details in a conditional block that checks if the environment is production. If so, return a generic error message (e.g., "An unexpected error occurred") and log the full details securely on the server side.

## 2025-12-25 - Memory Exhaustion in FastAPI UploadFile
**Vulnerability:** Unbounded memory consumption when reading uploaded files. `await file.read()` loads the entire file into RAM, bypassing spooling benefits if the file is large.
**Learning:** `MAX_IMAGE_BYTES` check was performed *after* reading the file, rendering it ineffective against memory exhaustion DoS.
**Prevention:** Always read uploaded files in chunks and enforce size limits incrementally.

## 2026-01-21 - Memory Exhaustion in Proxy Requests
**Vulnerability:** The `ui_proxy` endpoint in `server/apis/ui_proxy.py` was reading the entire request body into memory via `await request.body()` before checking its size, making it vulnerable to DoS attacks.
**Learning:** Checking payload size *after* reading into memory is too late. FastAPI/Starlette `request.body()` reads the full body.
**Prevention:** Use `request.stream()` to read body in chunks and validate size incrementally.
