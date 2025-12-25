## 2024-05-23 - Accessibility in Flutter custom buttons
**Learning:** Custom interactive widgets built with `InkWell` in Flutter often lack the "button" semantic role, unlike `MaterialButton` or `IconButton`.
**Action:** Always wrap `InkWell` used for button-like interactions with `Semantics(button: true, label: ...)` to ensure screen readers announce them correctly as actionable elements.
