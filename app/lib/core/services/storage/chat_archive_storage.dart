import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../utils/logger.dart';
import 'models/chat_session.dart';

export 'models/chat_session.dart';

/// Storage service for archived chat sessions
class ChatArchiveStorage {
  static const String boxName = 'chat_archives';
  static const _uuid = Uuid();

  final Box _box;

  ChatArchiveStorage(this._box);

  static Future<void> init() async {
    await Hive.openBox(boxName);
    Log.storage('Archive storage initialized');
  }

  /// Archive the current chat session
  Future<String> archiveSession({
    required List<Map<String, dynamic>> messages,
    String? customTitle,
  }) async {
    try {
      if (messages.isEmpty) {
        logger.w('Attempted to archive empty session');
        throw ArgumentError('Cannot archive empty session');
      }

      // Generate session title from first user message or use timestamp
      final title = customTitle ?? _generateSessionTitle(messages);
      final sessionId = _uuid.v4();

      final session = ChatSession(
        id: sessionId,
        title: title,
        messages: messages,
        timestamp: DateTime.now(),
        messageCount: messages.length,
      );

      await _box.put(sessionId, session.toMap());
      Log.storage('Archived: $title');

      return sessionId;
    } catch (e) {
      Log.e('Failed to archive session', e);
      rethrow;
    }
  }

  /// Get all archived sessions, sorted by timestamp (newest first)
  List<ChatSession> getArchivedSessions() {
    try {
      final sessions = _box.values
          .map(
            (item) =>
                ChatSession.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

      sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return sessions;
    } catch (e) {
      Log.e('Failed to get archived sessions', e);
      return [];
    }
  }

  /// Get a specific session by ID
  ChatSession? getSessionById(String sessionId) {
    try {
      final data = _box.get(sessionId);
      if (data == null) return null;

      return ChatSession.fromMap(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      Log.e('Failed to get session by ID', e);
      return null;
    }
  }

  /// Delete an archived session
  Future<void> deleteSession(String sessionId) async {
    try {
      await _box.delete(sessionId);
      Log.storage('Deleted session: $sessionId');
    } catch (e) {
      Log.e('Failed to delete session', e);
      rethrow;
    }
  }

  /// Rename an archived session
  Future<void> renameSession(String sessionId, String newTitle) async {
    try {
      final session = getSessionById(sessionId);
      if (session == null) {
        throw Exception('Session not found');
      }

      final updatedSession = session.copyWith(title: newTitle);
      await _box.put(sessionId, updatedSession.toMap());
      Log.storage('Renamed: $newTitle');
    } catch (e) {
      Log.e('Failed to rename session', e);
      rethrow;
    }
  }

  /// Update an existing archived session with new messages
  Future<void> updateSession({
    required String sessionId,
    required List<Map<String, dynamic>> messages,
  }) async {
    try {
      final session = getSessionById(sessionId);
      if (session == null) {
        throw Exception('Session not found');
      }

      final updatedSession = session.copyWith(
        messages: messages,
        messageCount: messages.length,
        timestamp: DateTime.now(), // Update timestamp to bring to top
      );

      await _box.put(sessionId, updatedSession.toMap());
      Log.storage('Updated session: ${messages.length} msgs');
    } catch (e) {
      Log.e('Failed to update session', e);
      rethrow;
    }
  }

  /// Search sessions by title or content
  List<ChatSession> searchSessions(String query) {
    try {
      if (query.trim().isEmpty) {
        return getArchivedSessions();
      }

      final lowerQuery = query.toLowerCase();
      final sessions = _box.values
          .map(
            (item) =>
                ChatSession.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .where((session) {
            // Search in title
            if (session.title.toLowerCase().contains(lowerQuery)) {
              return true;
            }

            // Search in message content
            for (final message in session.messages) {
              final content = (message['text'] as String? ?? '').toLowerCase();
              if (content.contains(lowerQuery)) {
                return true;
              }
            }

            return false;
          })
          .toList();

      sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return sessions;
    } catch (e) {
      Log.e('Failed to search sessions', e);
      return [];
    }
  }

  /// Get count of archived sessions
  int getSessionCount() {
    return _box.length;
  }

  /// Clear all archived sessions
  Future<void> clearAllArchives() async {
    try {
      await _box.clear();
      Log.storage('All archives cleared');
    } catch (e) {
      Log.e('Failed to clear archives', e);
      rethrow;
    }
  }

  /// Clear all archived sessions
  Future<void> clearAllSessions() async {
    try {
      await _box.clear();
      Log.storage('All sessions cleared');
    } catch (e) {
      Log.e('Failed to clear archives', e);
      rethrow;
    }
  }

  /// Clear all archived sessions except the specified one and important ones
  Future<void> clearAllSessionsExcept(
    String? excludeSessionId, {
    bool keepImportant = true,
  }) async {
    try {
      final keysToDelete = <dynamic>[];
      for (final key in _box.keys) {
        if (key == excludeSessionId) continue;
        if (keepImportant) {
          final session = getSessionById(key as String);
          if (session?.isImportant == true) continue;
        }
        keysToDelete.add(key);
      }
      await _box.deleteAll(keysToDelete);
      Log.storage('Cleared ${keysToDelete.length} sessions');
    } catch (e) {
      Log.e('Failed to clear archives', e);
      rethrow;
    }
  }

  /// Toggle important status for a session
  Future<void> toggleImportant(String sessionId) async {
    try {
      final session = getSessionById(sessionId);
      if (session == null) {
        throw Exception('Session not found');
      }

      final updatedSession = session.copyWith(isImportant: !session.isImportant);
      await _box.put(sessionId, updatedSession.toMap());
      Log.storage('Important: ${updatedSession.isImportant}');
    } catch (e) {
      Log.e('Failed to toggle important', e);
      rethrow;
    }
  }

  /// Generate a session title from messages
  String _generateSessionTitle(List<Map<String, dynamic>> messages) {
    // Find first user message
    final firstUserMessage = messages.firstWhere(
      (msg) => msg['isUser'] == true,
      orElse: () => {},
    );

    if (firstUserMessage.isNotEmpty) {
      final text = firstUserMessage['text'] as String;
      // Use first 50 characters or first line, whichever is shorter
      final firstLine = text.split('\n').first;
      final truncated = firstLine.length > 50
          ? '${firstLine.substring(0, 50)}...'
          : firstLine;
      return truncated;
    }

    // Fallback to timestamp-based title
    final now = DateTime.now();
    return 'Chat ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

final chatArchiveStorageProvider = Provider<ChatArchiveStorage>((ref) {
  final box = Hive.box(ChatArchiveStorage.boxName);
  return ChatArchiveStorage(box);
});

/// Notifier to track archive changes and trigger UI updates
class ArchiveRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final archiveRefreshProvider =
    NotifierProvider<ArchiveRefreshNotifier, int>(ArchiveRefreshNotifier.new);
