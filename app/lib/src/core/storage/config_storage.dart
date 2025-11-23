import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigStorage {
  static const _keyBaseUrl = 'base_url';
  static const _keyIsLocal = 'is_local';

  final SharedPreferences _prefs;

  ConfigStorage(this._prefs);

  Future<void> saveConfig({
    required String baseUrl,
    required bool isLocal,
  }) async {
    await _prefs.setString(_keyBaseUrl, baseUrl);
    await _prefs.setBool(_keyIsLocal, isLocal);
  }

  String? getBaseUrl() {
    return _prefs.getString(_keyBaseUrl);
  }

  bool getIsLocal() {
    return _prefs.getBool(_keyIsLocal) ?? false;
  }

  bool hasConfig() {
    return _prefs.containsKey(_keyBaseUrl);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final configStorageProvider = Provider<ConfigStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ConfigStorage(prefs);
});
