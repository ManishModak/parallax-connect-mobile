## 2024-05-23 - Chat Input Accessibility & Feedback
**Learning:** Users can be confused when a primary action button (Send) is clickable but does nothing (when input is empty).
**Action:** Always provide visual feedback for disabled states on primary action buttons. Use `onPressed: null` to leverage Flutter's built-in disabled semantics and styling support, but ensure custom containers also update their decoration to reflect the disabled state visually.
