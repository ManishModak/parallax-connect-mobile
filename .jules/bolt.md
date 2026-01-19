# Bolt's Journal

## 2024-05-22 - [Example]
**Learning:** [Example Learning]
**Action:** [Example Action]

## 2026-01-19 - Zero-copy buffer usage
**Learning:** In Python, `bytes(bytearray_obj)` creates a full memory copy. `io.BytesIO` and many C-extensions (like Pillow/OpenCV via EasyOCR) accept `bytearray` directly via buffer protocol.
**Action:** Always check if downstream libraries support buffer protocol/bytearray before casting to `bytes` to save memory on large blobs.
