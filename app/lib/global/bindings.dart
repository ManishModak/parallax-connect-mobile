import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/services/storage/chat_archive_storage.dart';
import '../core/services/storage/chat_history_storage.dart';
import '../core/utils/logger.dart';

/// Initialize app dependencies and services
///
/// This should be called before runApp() in main.dart
Future<void> initializeApp() async {
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    logger.w("No .env file found, using defaults.");
  }

  // Initialize storage
  await ChatHistoryStorage.init();
  await ChatArchiveStorage.init();

  // Archive last active chat and start fresh on app launch
  await _archiveAndClearActiveChat();
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
