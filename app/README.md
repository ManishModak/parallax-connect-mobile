# Parallax Connect (Beta)

![Beta](https://img.shields.io/badge/status-beta-orange)

A Flutter mobile app that connects to your self-hosted Parallax AI server. Access your private GPU-powered AI from anywhere.

## Features

- **Chat Interface** - Real-time streaming chat with markdown support
- **Multi-turn Conversations** - Context-aware responses with conversation history
- **QR Code Scanner** - Instant server connection via QR code
- **Dual Connection Modes** - Cloud (ngrok) and Local (Wi-Fi) support
- **Smart Search** - Provider choice (DuckDuckGo/Brave), depth (`normal/deep/deeper`), execution mode (mobile/middleware/parallax)
- **Edge + Server AI** - On-device OCR/image labeling; optional server OCR/document extraction
- **Document Support** - PDF text extraction and smart context chunking
- **Vision Pipeline** - Select edge/server pipeline; toggle thinking display
- **Chat History** - Local storage with export/share functionality
- **AI Settings** - Response styles, system prompt presets, streaming toggle, context window slider
- **Dark Theme** - Modern dark UI optimized for OLED displays

## 📥 Download Pre-built APK

Don't want to build from source? Download the latest APK:

- **[📱 Google Drive (Direct Download)](https://drive.google.com/file/d/1Rt_so8tpFoaGFlQLx14yIMJkE66vGH2N/view?usp=drive_link)**
- **[🏷️ GitHub Releases](https://github.com/ManishModak/parallax-connect/releases)**

## Key Controls (mobile)

- **Connection**: QR scan or manual URL; switch between Local/Cloud.
- **Web Search**: Enable/disable; provider selection; depth `normal/deep/deeper`; execution mode (mobile vs middleware vs parallax).
- **Documents**: Choose processing on device or server.
- **Vision**: Pipeline mode (edge/server) and OCR availability indicator.
- **Response Style**: Neutral/Concise/Formal/Casual/Detailed/Humorous or custom system prompt.
- **Privacy**: Password flows through QR handshake; history export/clear.

## Requirements

- Flutter 3.9.2 or higher
- Android 6.0+ / iOS 12.0+
- Camera permission (for QR scanning and vision features)
- Storage permission (for document processing)

## Getting Started

### 1. Install Dependencies

```bash
cd app
flutter pub get
```

### 2. Run the App

```bash
# Debug mode
flutter run

# Release mode
flutter run --release
```

### 3. Build for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app/                      # App-wide configuration
│   ├── app.dart              # Root widget (MaterialApp.router)
│   ├── constants/            # Colors, app constants
│   └── routes/               # GoRouter configuration
├── core/                     # Shared infrastructure
│   ├── network/              # Dio client, HTTP setup
│   ├── exceptions/           # Custom error classes
│   ├── services/             # Business logic services
│   ├── storage/             # Hive local storage
│   └── utils/                # Helpers, formatters
└── features/                 # Feature modules
    ├── chat/                 # Chat feature
    │   ├── data/             # Repositories, models
    │   ├── presentation/     # UI layer
    │   │   ├── views/        # Screen widgets
    │   │   ├── view_models/  # State management (Riverpod)
    │   │   └── widgets/     # Feature-specific widgets
    │   └── utils/            # Feature utilities
    ├── config/               # Server connection setup
    ├── settings/             # App settings
    └── splash/               # Splash screen
```

## Configuration

### Environment Variables

Create `assets/.env` for configuration:

```env
# Optional: Default server URL
DEFAULT_SERVER_URL=http://192.168.1.100:8000
```

### App Icons

Generate app icons after updating `assets/images/logo.png`:

```bash
flutter pub run flutter_launcher_icons
```

### Splash Screen

Generate native splash screen:

```bash
flutter pub run flutter_native_splash:create
```

## Key Dependencies

| Package | Purpose |
|---------|---------|
| flutter_riverpod | State management |
| dio | HTTP client |
| go_router | Navigation |
| hive_flutter | Local storage |
| mobile_scanner | QR code scanning |
| google_mlkit_* | On-device ML (OCR, labeling) |
| flutter_markdown | Markdown rendering |
| syncfusion_flutter_pdf | PDF processing |

## Connecting to Server

1. Start the Parallax Connect server on your computer
2. Open the app and tap "Scan QR Code"
3. Scan the QR code displayed in the server terminal
4. Start chatting!

Manual connection is also available by entering the server URL directly.

## Architecture

The app follows a feature-first architecture with MVVM pattern and Riverpod for state management:

- **app/** - App-wide configuration (themes, routing, constants)
- **core/** - Shared infrastructure (networking, storage, utilities, services)
- **features/** - Self-contained feature modules organized by business capability
  - Each feature has `data/` (repositories, models), `presentation/` (views, view_models, widgets), and optional `utils/`
  - `presentation/views/` contains screen widgets
  - `presentation/view_models/` contains Riverpod providers for state management
  - `presentation/widgets/` contains feature-specific UI components
- **Services** handle business logic and external communication
- **Storage** manages local persistence with Hive

## License

MIT
