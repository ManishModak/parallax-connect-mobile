import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/storage/chat_archive_storage.dart';
import 'core/storage/chat_history_storage.dart';
import 'core/storage/config_storage.dart';
import 'core/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    logger.w("No .env file found, using defaults.");
  }

  await ChatHistoryStorage.init();
  await ChatArchiveStorage.init();

  // Archive last active chat and start fresh on app launch
  await _archiveAndClearActiveChat();

  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(sharedPrefs)],
      child: const App(),
    ),
  );
}

/// Archives the last active chat session (if any) and clears history
/// so the user always starts with a fresh chat on app launch.
Future<void> _archiveAndClearActiveChat() async {
  try {
    final historyBox = Hive.box(ChatHistoryStorage.boxName);
    final archiveBox = Hive.box(ChatArchiveStorage.boxName);

    // Get current history messages
    final messages = historyBox.values
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    // Only archive if there are messages
    if (messages.isNotEmpty) {
      // Create archive storage instance to use its archiveSession method
      final archiveStorage = ChatArchiveStorage(archiveBox);
      await archiveStorage.archiveSession(messages: messages);
      Log.storage('Archived active chat on startup');

      // Clear the active history for fresh start
      await historyBox.clear();
      Log.storage('Cleared history for fresh start');
    }
  } catch (e) {
    Log.e('Failed to archive active chat on startup', e);
    // Don't rethrow - app should still start even if archiving fails
  }
}
