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
  final String currentSearchQuery;
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
    this.currentSearchQuery = '',
    this.searchStatusMessage = '',
    this.webSearchMode = 'deep',
    this.editingMessage,
    this.lastSearchMetadata,
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
    bool? isAnalyzingIntent,
    bool? isSearchingWeb,
    String? currentSearchQuery,
    String? searchStatusMessage,
    String? webSearchMode,
    ChatMessage? editingMessage,
    Map<String, dynamic>? lastSearchMetadata,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Allow null to clear error
      isPrivateMode: isPrivateMode ?? this.isPrivateMode,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingContent: streamingContent ?? this.streamingContent,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      isThinking: isThinking ?? this.isThinking,
      isAnalyzingIntent: isAnalyzingIntent ?? this.isAnalyzingIntent,
      isSearchingWeb: isSearchingWeb ?? this.isSearchingWeb,
      currentSearchQuery: currentSearchQuery ?? this.currentSearchQuery,
      searchStatusMessage: searchStatusMessage ?? this.searchStatusMessage,
      webSearchMode: webSearchMode ?? this.webSearchMode,
      editingMessage: editingMessage, // Allow null to clear editing state
      lastSearchMetadata: lastSearchMetadata,
    );
  }
}
