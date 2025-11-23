import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/chat_history_storage.dart';
import '../data/chat_repository.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'],
      isUser: map['isUser'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  ChatState({this.messages = const [], this.isLoading = false, this.error});

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatController extends Notifier<ChatState> {
  late final ChatRepository _repository;
  late final ChatHistoryStorage _historyStorage;

  @override
  ChatState build() {
    _repository = ref.read(chatRepositoryProvider);
    _historyStorage = ref.read(chatHistoryStorageProvider);
    _loadHistory();
    return ChatState();
  }

  void _loadHistory() {
    final history = _historyStorage.getHistory();
    final messages = history.map((e) => ChatMessage.fromMap(e)).toList();
    state = state.copyWith(messages: messages);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    await _historyStorage.saveMessage(userMessage.toMap());

    try {
      final response = await _repository.generateText(text);
      final aiMessage = ChatMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isLoading: false,
      );

      await _historyStorage.saveMessage(aiMessage.toMap());
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> clearHistory() async {
    await _historyStorage.clearHistory();
    state = state.copyWith(messages: []);
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(() {
  return ChatController();
});
