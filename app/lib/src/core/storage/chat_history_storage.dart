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
    logger.storage('Chat history storage initialized');
  }

  /// Save a message to history
  Future<void> saveMessage(Map<String, dynamic> message) async {
    try {
      // Validate message has required fields
      if (!_isValidMessage(message)) {
        logger.w('Attempted to save invalid message: $message');
        throw ArgumentError('Message must contain required fields');
      }

      await _box.add(message);
      logger.storage('Message saved to history');
    } catch (e) {
      logger.e('Failed to save message: $e');
      rethrow;
    }
  }

  /// Get all chat history
  List<Map<String, dynamic>> getHistory() {
    try {
      final messages = _box.values
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      logger.storage('Retrieved ${messages.length} messages from history');
      return messages;
    } catch (e) {
      logger.e('Failed to get history: $e');
      return [];
    }
  }

  /// Search messages by content
  List<Map<String, dynamic>> searchMessages(String query) {
    try {
      if (query.trim().isEmpty) {
        return getHistory();
      }

      final lowerQuery = query.toLowerCase();
      final messages = _box.values
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((message) {
            final content = (message['content'] as String? ?? '').toLowerCase();
            return content.contains(lowerQuery);
          })
          .toList();

      logger.storage('Found ${messages.length} messages for query: $query');
      return messages;
    } catch (e) {
      logger.e('Failed to search messages: $e');
      return [];
    }
  }

  /// Get messages after a specific timestamp
  List<Map<String, dynamic>> getMessagesSince(DateTime since) {
    try {
      final sinceMillis = since.millisecondsSinceEpoch;
      final messages = _box.values
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((message) {
            final timestamp = message['timestamp'] as int? ?? 0;
            return timestamp >= sinceMillis;
          })
          .toList();

      logger.storage('Retrieved ${messages.length} messages since $since');
      return messages;
    } catch (e) {
      logger.e('Failed to get messages since: $e');
      return [];
    }
  }

  /// Clear all chat history
  Future<void> clearHistory() async {
    try {
      await _box.clear();
      logger.storage('Chat history cleared');
    } catch (e) {
      logger.e('Failed to clear history: $e');
      rethrow;
    }
  }

  /// Get count of messages
  int getMessageCount() {
    return _box.length;
  }

  /// Validate message structure
  bool _isValidMessage(Map<String, dynamic> message) {
    return message.containsKey('content') &&
        message.containsKey('role') &&
        message.containsKey('timestamp');
  }
}

final chatHistoryStorageProvider = Provider<ChatHistoryStorage>((ref) {
  final box = Hive.box(ChatHistoryStorage.boxName);
  return ChatHistoryStorage(box);
});
