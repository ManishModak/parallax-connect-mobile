import '../../data/models/chat_message.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final bool isPrivateMode;
  final String? currentSessionId;

  // Streaming state
  final bool isStreaming;
  final String streamingContent;
  final String thinkingContent;
  final bool isThinking;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.isPrivateMode = false,
    this.currentSessionId,
    this.isStreaming = false,
    this.streamingContent = '',
    this.thinkingContent = '',
    this.isThinking = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    bool? isPrivateMode,
    String? currentSessionId,
    bool? isStreaming,
    String? streamingContent,
    String? thinkingContent,
    bool? isThinking,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isPrivateMode: isPrivateMode ?? this.isPrivateMode,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingContent: streamingContent ?? this.streamingContent,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      isThinking: isThinking ?? this.isThinking,
    );
  }
}
