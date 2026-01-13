# Bolt's Journal

## 2024-05-22 - [Example]
**Learning:** [Example Learning]
**Action:** [Example Action]

## 2024-10-24 - [Avoid bytearray to bytes conversion for large blobs]
**Learning:** Casting `bytearray` to `bytes` creates a full copy of the data. For large payloads like images (8MB+), this significantly spikes memory usage. Libraries like PIL (`Image.open`) and EasyOCR often accept `bytearray` directly or via `io.BytesIO`.
**Action:** Type hints should use `Union[bytes, bytearray]` and explicit casting should be avoided in data ingestion pipelines.
