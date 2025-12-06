# Changelog

## [0.5.0] - 2025-12-06

### Added

- **Smart Web Search** with 3 depth levels (Normal/Deep/Deeper)
- **Vision Pipeline** with edge (on-device) and server OCR modes
- **Document Processing** with PDF extraction and context chunking
- **Server-side OCR** via PaddleOCR/EasyOCR
- OpenAI-compatible `/v1/chat/completions` endpoint
- Password protection for API endpoints
- Response style presets (Neutral/Concise/Formal/Casual/Detailed)
- Export chat history as PDF or text
- Haptic feedback throughout the app
- Improved streaming with thinking indicators

### Changed

- Upgraded architecture to feature-first MVVM with Riverpod
- Enhanced chat UI with markdown rendering and code highlighting
- Refined settings panel with grouped controls
- Better error handling and user feedback

### Fixed

- Connection stability improvements
- Unicode support in PDF exports
- Streaming response handling edge cases

---

## [0.1.0-beta] - 2025-11-28

### Added

- Initial beta release of Parallax Connect
- Chat interface with streaming support
- QR code scanner for easy server connection
- Local and Cloud connection modes
- On-device AI features (OCR, Image Labeling)
- Chat history with export functionality
- Settings for AI parameters
