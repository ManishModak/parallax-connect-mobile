import '../../models/chat_message.dart';

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

  // Smart Search Status
  final bool isAnalyzingIntent;
  final bool isSearchingWeb;
  final String searchStatusMessage;
  final String webSearchMode; // 'off', 'normal', 'deep', 'deeper'
  final ChatMessage? editingMessage;
  final Map<String, dynamic>? lastSearchMetadata;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.isPrivateMode = false,
    this.currentSessionId,
    this.isStreaming = false,
    this.streamingContent = '',
    this.thinkingContent = '',
    this.isThinking = false,
    this.isAnalyzingIntent = false,
    this.isSearchingWeb = false,
    this.searchStatusMessage = '',
    this.webSearchMode = 'deep',
    this.editingMessage,
    this.lastSearchMetadata,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isPrivateMode,
    String? currentSessionId,
    bool? isStreaming,
    String? streamingContent,
    String? thinkingContent,
    bool? isThinking,
    bool? isAnalyzingIntent,
    bool? isSearchingWeb,
    String? searchStatusMessage,
    String? webSearchMode,
    ChatMessage? editingMessage,
    bool clearEditingMessage = false,
    Map<String, dynamic>? lastSearchMetadata,
    bool clearLastSearchMetadata = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isPrivateMode: isPrivateMode ?? this.isPrivateMode,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingContent: streamingContent ?? this.streamingContent,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      isThinking: isThinking ?? this.isThinking,
      isAnalyzingIntent: isAnalyzingIntent ?? this.isAnalyzingIntent,
      isSearchingWeb: isSearchingWeb ?? this.isSearchingWeb,
      searchStatusMessage: searchStatusMessage ?? this.searchStatusMessage,
      webSearchMode: webSearchMode ?? this.webSearchMode,
      editingMessage: clearEditingMessage
          ? null
          : (editingMessage ?? this.editingMessage),
      lastSearchMetadata: clearLastSearchMetadata
          ? null
          : (lastSearchMetadata ?? this.lastSearchMetadata),
    );
  }
}
