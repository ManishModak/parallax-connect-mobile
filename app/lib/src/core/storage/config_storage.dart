import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

import '../constants/app_constants.dart';
import '../utils/logger.dart';
import '../utils/validators.dart';

/// Storage service for app configuration
class ConfigStorage {
  // Deterministic encryption key derived from fixed seed
  static const _encryptionSeed = 'parallax_connect_password_seed';
  static final encrypt.Key _encryptionKey = encrypt.Key(
    Uint8List.fromList(
      sha256.convert(utf8.encode(_encryptionSeed)).bytes,
    ),
  );
  static final encrypt.Encrypter _encrypter =
      encrypt.Encrypter(encrypt.AES(_encryptionKey));
  static final encrypt.IV _iv = encrypt.IV.fromLength(16);

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
        // Encrypt password before storing
        final encrypted = _encrypter.encrypt(password, iv: _iv);
        await _prefs.setString(StorageKeys.password, encrypted.base64);
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
      final encryptedPassword = _prefs.getString(StorageKeys.password);
      if (encryptedPassword == null) return null;

      final encrypted = encrypt.Encrypted.fromBase64(encryptedPassword);
      return _encrypter.decrypt(encrypted, iv: _iv);
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

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final configStorageProvider = Provider<ConfigStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ConfigStorage(prefs);
});
