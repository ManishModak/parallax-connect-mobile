/// Application metadata constants
class AppMetadata {
  static const String appName = 'Parallax Connect';
  static const String version = '1.0.0';
  static const String packageName = 'com.parallax.connect';
}

/// Test mode configuration
class TestConfig {
  // 🧪 TEST MODE - Set to true to test UI without backend
  static const bool enabled = true;

  // 🧪 MOCK RESPONSE TYPE - Choose which type of response to test
  // Options: 'plain', 'code', 'markdown', 'mixed', 'long'
  static const String mockResponseType = 'long';
}

/// Network timeout constants
class NetworkTimeouts {
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}

/// Storage keys constants
class StorageKeys {
  // Config storage
  static const String baseUrl = 'base_url';
  static const String isLocal = 'is_local';
  static const String password = 'password';

  // Chat history
  static const String chatHistory = 'chat_history';
}

/// API constants
class ApiConstants {
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(milliseconds: 1000);
}

/// File size limits
class FileLimits {
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5 MB
}
