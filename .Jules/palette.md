## 2024-05-23 - Interactive Pills and Bubbles
**Learning:** Custom interactive widgets like "pills" or "bubbles" (using `InkWell` or `GestureDetector`) are often invisible to screen readers as actionable elements unless explicitly wrapped in `Semantics` with `button: true`.
**Action:** Always wrap custom interactive containers in `Semantics(button: true, label: 'Action description', child: ...)` to ensure they are announced as buttons.

**Learning:** Purely visual loading states (like Shimmer effects) leave screen reader users in the dark.
**Action:** Wrap loading indicators in `Semantics(label: 'Loading...', child: ...)` so non-sighted users know the system is busy.
