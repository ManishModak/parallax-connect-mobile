# Parallax Connect

A Flutter mobile app that connects to your self-hosted Parallax AI server. Access your private GPU-powered AI from anywhere.

## Features

- **Chat Interface** - Real-time streaming chat with markdown support
- **Multi-turn Conversations** - Context-aware responses with conversation history
- **QR Code Scanner** - Instant server connection via QR code
- **Dual Connection Modes** - Cloud (ngrok) and Local (Wi-Fi) support
- **Edge AI Processing** - On-device OCR and image labeling via ML Kit
- **Document Support** - PDF text extraction and smart context chunking
- **Chat History** - Local storage with export/share functionality
- **AI Settings** - Adjustable temperature, tokens, and sampling parameters
- **Dark Theme** - Modern dark UI optimized for OLED displays

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
└── src/
    ├── app.dart              # App widget & providers
    ├── core/
    │   ├── constants/        # Colors, app constants
    │   ├── networking/       # Dio client, exceptions
    │   ├── router/           # GoRouter configuration
    │   ├── services/         # Business logic services
    │   ├── storage/          # Hive local storage
    │   └── utils/            # Helpers, formatters
    └── features/
        ├── chat/             # Chat screen & logic
        ├── config/           # Server connection setup
        ├── settings/         # App settings
        └── splash/           # Splash screen
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

The app follows a feature-first architecture with Riverpod for state management:

- **Features** are self-contained modules with their own data/presentation layers
- **Core** contains shared utilities, services, and infrastructure
- **Services** handle business logic and external communication
- **Storage** manages local persistence with Hive

## License

MIT
