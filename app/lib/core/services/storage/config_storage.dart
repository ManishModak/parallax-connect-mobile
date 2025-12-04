import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

import '../../../app/constants/app_constants.dart';
import '../../../global/providers.dart';
import '../../utils/logger.dart';
import '../../utils/validators.dart';

/// Storage service for app configuration
class ConfigStorage {
  // Deterministic encryption key derived from fixed seed
  static const _encryptionSeed = 'parallax_connect_password_seed';
  static final encrypt.Key _encryptionKey = encrypt.Key(
    Uint8List.fromList(sha256.convert(utf8.encode(_encryptionSeed)).bytes),
  );
  static final encrypt.Encrypter _encrypter = encrypt.Encrypter(
    encrypt.AES(_encryptionKey),
  );

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

      await _prefs.setString(StorageKeys.baseUrl, baseUrl);
      await _prefs.setBool(StorageKeys.isLocal, isLocal);

      if (password != null && password.isNotEmpty) {
        // Generate random IV for each encryption (more secure)
        final iv = encrypt.IV.fromSecureRandom(16);
        final encrypted = _encrypter.encrypt(password, iv: iv);
        // Store as "iv:ciphertext" format
        final stored = '${iv.base64}:${encrypted.base64}';
        await _prefs.setString(StorageKeys.password, stored);
      } else {
        await _prefs.remove(StorageKeys.password);
      }

      Log.storage('Config saved');
    } catch (e) {
      Log.e('Failed to save config', e);
      rethrow;
    }
  }

  String? getBaseUrl() {
    try {
      return _prefs.getString(StorageKeys.baseUrl);
    } catch (e) {
      Log.e('Failed to get base URL', e);
      return null;
    }
  }

  bool getIsLocal() {
    try {
      return _prefs.getBool(StorageKeys.isLocal) ?? false;
    } catch (e) {
      Log.e('Failed to get connection mode', e);
      return false;
    }
  }

  String? getPassword() {
    try {
      final stored = _prefs.getString(StorageKeys.password);
      if (stored == null) return null;

      // Parse "iv:ciphertext" format
      final parts = stored.split(':');
      if (parts.length != 2) {
        Log.w('Invalid password format, clearing');
        _prefs.remove(StorageKeys.password);
        return null;
      }

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      return _encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      Log.e('Failed to get password', e);
      return null;
    }
  }

  /// Check if configuration exists
  bool hasConfig() {
    return _prefs.containsKey(StorageKeys.baseUrl);
  }

  /// Clear all configuration
  Future<void> clearConfig() async {
    try {
      await _prefs.remove(StorageKeys.baseUrl);
      await _prefs.remove(StorageKeys.isLocal);
      await _prefs.remove(StorageKeys.password);
      Log.storage('Config cleared');
    } catch (e) {
      Log.e('Failed to clear config', e);
      rethrow;
    }
  }
}

final configStorageProvider = Provider<ConfigStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ConfigStorage(prefs);
});
