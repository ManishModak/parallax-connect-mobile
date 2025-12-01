import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'global/bindings.dart';
import 'global/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app dependencies
  await initializeApp();

  // Get SharedPreferences instance
  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(sharedPrefs)],
      child: const App(),
    ),
  );
}
