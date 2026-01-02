## 2024-05-23 - Interactive Pills and Bubbles

**Learning:** Custom interactive widgets like "pills" or "bubbles" (using `InkWell` or `GestureDetector`) are often invisible to screen readers as actionable elements unless explicitly wrapped in `Semantics` with `button: true`.
**Action:** Always wrap custom interactive containers in `Semantics(button: true, label: 'Action description', child: ...)` to ensure they are announced as buttons.

**Learning:** Purely visual loading states (like Shimmer effects) leave screen reader users in the dark.
**Action:** Wrap loading indicators in `Semantics(label: 'Loading...', child: ...)` so non-sighted users know the system is busy.

## 2025-02-14 - Icon Affordance

**Learning:** Using a state-completion icon (like a checkmark) for an action button (like "Copy") before the action is taken confuses users about the button's purpose and state.
**Action:** Use action-oriented icons (e.g., Clipboard/Copy) for the default state, and switch to completion icons (e.g., Check) only after the action is successful.

## 2025-02-14 - Interaction Feedback

**Learning:** `GestureDetector` provides no visual feedback on touch, making the UI feel unresponsive.
**Action:** Replace `GestureDetector` with `InkWell` (wrapped in `Material`) for interactive elements to provide ripple effects and better focus states.

## 2025-02-14 - Touch Targets

**Learning:** Small icons with tight padding (e.g., < 24dp) are difficult to tap accurately.
**Action:** Ensure interactive elements have a hit test area of at least 40x40dp (or close to it) by increasing padding or using `IconButton`/`InkWell` with larger constraints.
## 2024-05-24 - Navigation in Long Lists

**Learning:** In chat interfaces or long lists, users often lose context when scrolling up to read history. Without a quick way to return to the bottom (latest content), the experience feels tedious.
**Action:** Implement a floating "Scroll to Bottom" button that appears when the user scrolls away from the latest content. Ensure it is keyboard accessible and provides feedback.
