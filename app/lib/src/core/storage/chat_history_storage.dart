import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ChatHistoryStorage {
  static const _boxName = 'chat_history';

  final Box _box;

  ChatHistoryStorage(this._box);

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  Future<void> saveMessage(Map<String, dynamic> message) async {
    await _box.add(message);
  }

  List<Map<String, dynamic>> getHistory() {
    return _box.values.cast<Map<String, dynamic>>().toList();
  }

  Future<void> clearHistory() async {
    await _box.clear();
  }
}

final chatHistoryStorageProvider = Provider<ChatHistoryStorage>((ref) {
  final box = Hive.box('chat_history');
  return ChatHistoryStorage(box);
});
