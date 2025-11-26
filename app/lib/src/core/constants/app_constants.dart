/// Application metadata constants
class AppMetadata {
  static const String appName = 'Parallax Connect';
  static const String version = '1.0.0';
  static const String packageName = 'com.parallax.connect';
}

/// Test mode configuration
class TestConfig {
  // 🧪 TEST MODE - Set to true to test UI without backend
  static const bool enabled = false;

  // 🧪 MOCK RESPONSE TYPE - Choose which type of response to test
  // Options: 'plain', 'code', 'markdown', 'mixed', 'long'
  static const String mockResponseType = 'long';
}

/// Storage keys constants
class StorageKeys {
  // Config storage
  static const String baseUrl = 'base_url';
  static const String isLocal = 'is_local';
  static const String password = 'password';
}
