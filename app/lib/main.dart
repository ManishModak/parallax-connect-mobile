import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/utils/haptics_helper.dart';
import 'features/settings/data/settings_storage.dart';
import 'global/bindings.dart';
import 'global/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app dependencies
  await initializeApp();

  // Get SharedPreferences instance
  final sharedPrefs = await SharedPreferences.getInstance();
  final settingsStorage = SettingsStorage(sharedPrefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        hapticsSettingsProvider.overrideWithValue(settingsStorage),
      ],
      child: const App(),
    ),
  );
}
