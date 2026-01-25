## 2024-05-24 - Information Leakage in Error Handling
**Vulnerability:** The `handle_service_error` function in `server/utils/error_handler.py` was exposing raw exception messages to API clients in the `detail` field. This could leak sensitive internal information such as file paths, database connection strings, or internal IP addresses if an exception occurred.
**Learning:** Default error handlers often prioritize developer convenience (showing the full error) over security. Explicit checks for `DEBUG_MODE` or environment type are crucial to sanitize errors in production.
**Prevention:** Always wrap error details in a conditional block that checks if the environment is production. If so, return a generic error message (e.g., "An unexpected error occurred") and log the full details securely on the server side.

## 2025-12-25 - Memory Exhaustion in FastAPI UploadFile
**Vulnerability:** Unbounded memory consumption when reading uploaded files. `await file.read()` loads the entire file into RAM, bypassing spooling benefits if the file is large.
**Learning:** `MAX_IMAGE_BYTES` check was performed *after* reading the file, rendering it ineffective against memory exhaustion DoS.
**Prevention:** Always read uploaded files in chunks and enforce size limits incrementally.

## 2026-01-25 - Path Traversal via Double URL Encoding
**Vulnerability:** The UI proxy endpoint blindly passed the `path` parameter to the backend after a single decoding step by the framework. Attackers could bypass basic `..` checks by using double-encoded sequences (e.g., `%252e%252e`).
**Learning:** Standard framework decoding is insufficient for security boundaries where the input is re-used in a way that might trigger further decoding (e.g., passing to another URL-handling library or proxy).
**Prevention:** Implement recursive URL decoding (with a loop limit) to canonicalize the input before applying security checks like `..` detection.
