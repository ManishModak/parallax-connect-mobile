import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../utils/logger.dart';

/// Storage service for chat history
class ChatHistoryStorage {
  static const String boxName = 'chat_history';

  final Box _box;

  ChatHistoryStorage(this._box);

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxName);
    Log.storage('History storage initialized');
  }

  Future<void> saveMessage(Map<String, dynamic> message) async {
    try {
      if (!_isValidMessage(message)) {
        Log.w('Invalid message format');
        throw ArgumentError('Message must contain required fields');
      }
      await _box.add(message);
    } catch (e) {
      Log.e('Failed to save message', e);
      rethrow;
    }
  }

  List<Map<String, dynamic>> getHistory() {
    try {
      return _box.values
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      Log.e('Failed to get history', e);
      return [];
    }
  }

  List<Map<String, dynamic>> searchMessages(String query) {
    try {
      if (query.trim().isEmpty) return getHistory();

      final lowerQuery = query.toLowerCase();
      return _box.values
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((message) {
            final content = (message['text'] as String? ?? '').toLowerCase();
            return content.contains(lowerQuery);
          })
          .toList();
    } catch (e) {
      Log.e('Failed to search messages', e);
      return [];
    }
  }

  List<Map<String, dynamic>> getMessagesSince(DateTime since) {
    try {
      final sinceMillis = since.millisecondsSinceEpoch;
      return _box.values
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((message) {
            final timestamp = message['timestamp'] as int? ?? 0;
            return timestamp >= sinceMillis;
          })
          .toList();
    } catch (e) {
      Log.e('Failed to get messages since', e);
      return [];
    }
  }

  Future<void> clearHistory() async {
    try {
      await _box.clear();
      Log.storage('History cleared');
    } catch (e) {
      Log.e('Failed to clear history', e);
      rethrow;
    }
  }

  /// Get count of messages
  int getMessageCount() {
    return _box.length;
  }

  /// Validate message structure
  bool _isValidMessage(Map<String, dynamic> message) {
    return message.containsKey('text') &&
        message.containsKey('isUser') &&
        message.containsKey('timestamp');
  }
}

final chatHistoryStorageProvider = Provider<ChatHistoryStorage>((ref) {
  final box = Hive.box(ChatHistoryStorage.boxName);
  return ChatHistoryStorage(box);
});
