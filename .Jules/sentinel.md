## 2024-05-23 - Path Traversal via Encoding
**Vulnerability:** The UI proxy endpoint (`/ui/{path:path}`) was vulnerable to path traversal attacks using double-encoded payloads (e.g., `%252e%252e` for `..`). The original check only looked for literal `..` in the raw path string, which frameworks/proxies might decode differently than the application check.

**Learning:** Naive string matching on path parameters is insufficient for security controls. Attackers can use various encoding schemes (URL encoding, double encoding, Unicode) to bypass simple string filters.

**Prevention:** Always normalize and decode user input before applying security checks. For path traversal, recursively decode URL-encoded characters (up to a reasonable limit) and check against known bad patterns (`..`, absolute paths) on the fully decoded string.
