import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

import '../utils/logger.dart';
import '../utils/validators.dart';

/// Storage service for app configuration
class ConfigStorage {
  static const _keyBaseUrl = 'base_url';
  static const _keyIsLocal = 'is_local';
  static const _keyPassword = 'password';

  // Simple encryption key (in production, use secure key storage)
  static final _encryptionKey = encrypt.Key.fromLength(32);
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
  static final _iv = encrypt.IV.fromLength(16);

  final SharedPreferences _prefs;

  ConfigStorage(this._prefs);

  /// Save configuration
  Future<void> saveConfig({
    required String baseUrl,
    required bool isLocal,
    String? password,
  }) async {
    try {
      // Validate URL
      if (!Validators.isValidUrl(baseUrl) &&
          !Validators.isValidLocalhost(baseUrl)) {
        throw ArgumentError('Invalid URL format');
      }

      await _prefs.setString(_keyBaseUrl, baseUrl);
      await _prefs.setBool(_keyIsLocal, isLocal);

      if (password != null && password.isNotEmpty) {
        // Encrypt password before storing
        final encrypted = _encrypter.encrypt(password, iv: _iv);
        await _prefs.setString(_keyPassword, encrypted.base64);
      } else {
        await _prefs.remove(_keyPassword);
      }

      logger.storage('Configuration saved');
    } catch (e) {
      logger.e('Failed to save config: $e');
      rethrow;
    }
  }

  /// Get base URL
  String? getBaseUrl() {
    try {
      return _prefs.getString(_keyBaseUrl);
    } catch (e) {
      logger.e('Failed to get base URL: $e');
      return null;
    }
  }

  /// Get connection mode (local or cloud)
  bool getIsLocal() {
    try {
      return _prefs.getBool(_keyIsLocal) ?? false;
    } catch (e) {
      logger.e('Failed to get connection mode: $e');
      return false;
    }
  }

  /// Get password (decrypted)
  String? getPassword() {
    try {
      final encryptedPassword = _prefs.getString(_keyPassword);
      if (encryptedPassword == null) return null;

      // Decrypt password
      final encrypted = encrypt.Encrypted.fromBase64(encryptedPassword);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      logger.e('Failed to get password: $e');
      return null;
    }
  }

  /// Check if configuration exists
  bool hasConfig() {
    return _prefs.containsKey(_keyBaseUrl);
  }

  /// Clear all configuration
  Future<void> clearConfig() async {
    try {
      await _prefs.remove(_keyBaseUrl);
      await _prefs.remove(_keyIsLocal);
      await _prefs.remove(_keyPassword);
      logger.storage('Configuration cleared');
    } catch (e) {
      logger.e('Failed to clear config: $e');
      rethrow;
    }
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final configStorageProvider = Provider<ConfigStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ConfigStorage(prefs);
});
