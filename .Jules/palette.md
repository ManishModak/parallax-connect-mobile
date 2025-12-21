## 2024-05-22 - Visual Focus and Semantics
**Learning:** `InputDecoration` in Flutter doesn't have a `semanticsLabel` property. To add accessibility labels to a `TextField`, you must wrap it in a `Semantics` widget.
**Action:** Always wrap `TextField` in `Semantics` when `labelText` is not used or insufficient.

**Learning:** Visual focus states are critical for keyboard users and general UX. Using a `FocusNode` listener to update UI state is a reliable pattern.
**Action:** Consider creating a reusable `FocusAwareContainer` if this pattern is needed frequently.
