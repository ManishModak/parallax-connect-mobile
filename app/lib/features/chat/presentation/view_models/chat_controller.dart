import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/system/connectivity_service.dart';
import '../../../../core/services/utilities/document_service.dart';
import '../../../../core/services/ai/smart_search_service.dart';
import '../../../../core/services/ai/vision_service.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../../../../core/utils/logger.dart';
import '../../data/repositories/chat_repository.dart';
import '../../../../core/services/storage/chat_history_storage.dart';
import '../../../../core/services/storage/chat_archive_storage.dart';
import '../../../../core/services/storage/config_storage.dart';
import '../../../settings/data/settings_storage.dart';
import '../../models/chat_message.dart';
import '../state/chat_state.dart';
import 'chat_send_orchestrator.dart';

class ChatController extends Notifier<ChatState> {
  late final ChatRepository _repository;
  late final SettingsStorage _settingsStorage;
  late final ChatHistoryStorage _historyStorage;
  late final ChatArchiveStorage _archiveStorage;
  late final ConfigStorage _configStorage;
  late final VisionService _visionService;
  late final ConnectivityService _connectivityService;
  late final DocumentService _documentService;
  late final HapticsHelper _hapticsHelper;
  late final SmartSearchService _smartSearchService;
  late final ChatSendOrchestrator _sendOrchestrator;

  // Tracks the active streaming subscription so we can properly cancel it when
  // starting a new stream or when this controller is disposed.
  StreamSubscription<StreamEvent>? _streamSubscription;

  @override
  ChatState build() {
    _repository = ref.read(chatRepositoryProvider);
    _settingsStorage = ref.read(settingsStorageProvider);
    _historyStorage = ref.read(chatHistoryStorageProvider);
    _archiveStorage = ref.read(chatArchiveStorageProvider);
    _configStorage = ref.read(configStorageProvider);
    _visionService = ref.read(visionServiceProvider);
    _connectivityService = ref.read(connectivityServiceProvider);
    _documentService = ref.read(documentServiceProvider);
    _hapticsHelper = ref.read(hapticsHelperProvider);
    _smartSearchService = ref.read(smartSearchServiceProvider);
    _sendOrchestrator = ChatSendOrchestrator(
      settingsStorage: _settingsStorage,
      configStorage: _configStorage,
      visionService: _visionService,
      connectivityService: _connectivityService,
      documentService: _documentService,
      smartSearchService: _smartSearchService,
    );

    // Properly dispose stream subscription when controller is disposed
    ref.onDispose(() {
      _streamSubscription?.cancel();
    });

    final messages = _historyStorage.getHistory();
    return ChatState(
      messages: messages.map((m) => ChatMessage.fromMap(m)).toList(),
    );
  }

  void startNewChat() {
    state = state.copyWith(
      messages: [],
      clearError: true,
      currentSessionId: null,
      isPrivateMode: false,
      webSearchMode: 'deep',
    );
  }

  void setWebSearchMode(String mode) {
    state = state.copyWith(webSearchMode: mode);
  }

  void togglePrivateMode() {
    state = state.copyWith(isPrivateMode: !state.isPrivateMode);
  }

  void disablePrivateMode() {
    state = state.copyWith(isPrivateMode: false);
  }

  Future<void> retryMessage(ChatMessage message) async {
    // Remove the failed message and any subsequent AI response (if any)
    final index = state.messages.indexOf(message);
    if (index != -1) {
      final newMessages = state.messages.sublist(0, index);
      state = state.copyWith(messages: newMessages);
      // Resend the message
      await sendMessage(message.text, attachmentPaths: message.attachmentPaths);
    }
  }

  void startEditing(ChatMessage message) {
    state = state.copyWith(editingMessage: message);
  }

  void cancelEditing() {
    state = state.copyWith(clearEditingMessage: true);
  }

  Future<void> submitEdit(String newText) async {
    final message = state.editingMessage;
    if (message == null) return;

    // Clear editing state
    state = state.copyWith(clearEditingMessage: true);

    // Remove the message and all subsequent messages
    final index = state.messages.indexOf(message);
    if (index != -1) {
      final newMessages = state.messages.sublist(0, index);
      state = state.copyWith(messages: newMessages);
      // Send the new text
      await sendMessage(newText, attachmentPaths: message.attachmentPaths);
    }
  }

  Future<void> editMessage(ChatMessage message, String newText) async {
    // Legacy method, keeping for compatibility if needed, but submitEdit is preferred for inline flow
    startEditing(message);
    await submitEdit(newText);
  }

  Future<void> sendMessage(
    String text, {
    List<String> attachmentPaths = const [],
  }) async {
    if (text.trim().isEmpty && attachmentPaths.isEmpty) return;

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      attachmentPaths: attachmentPaths,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      clearError: true,
    );

    // Only save to history if not in private mode
    if (!state.isPrivateMode) {
      await _historyStorage.saveMessage(userMessage.toMap());
    }

    try {
      await _sendOrchestrator.send(
        text: text,
        attachmentPaths: attachmentPaths,
        initialState: state,
        setState: (newState) => state = newState,
        sendStreaming: _sendStreamingMessage,
        sendNonStreaming: _sendNonStreamingMessage,
        finalizeMessage: _finalizeMessage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isStreaming: false,
        isAnalyzingIntent: false,
        isSearchingWeb: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> _sendStreamingMessage(
    String contextText, {
    bool disableWebSearch = false,
  }) async {
    final systemPrompt = _settingsStorage.getSystemPrompt();
    final history = state.messages.length > 1
        ? state.messages.sublist(0, state.messages.length - 1)
        : <ChatMessage>[];

    // Trigger haptic to signal streaming is starting
    _hapticsHelper.triggerStreamingStart();

    state = state.copyWith(
      isLoading: false,
      isStreaming: true,
      streamingContent: '',
      thinkingContent: '',
      isThinking: false,
    );

    final completer = Completer<void>();

    // Cancel any existing stream before starting a new one to avoid multiple
    // concurrent listeners updating state at the same time.
    await _streamSubscription?.cancel();

    _streamSubscription = _repository
        .generateTextStream(
          contextText,
          systemPrompt: systemPrompt,
          history: history,
          webSearchEnabled: !disableWebSearch && state.webSearchMode != 'off',
          webSearchDepth: state.webSearchMode,
        )
        .listen(
          (event) {
            if (event.isThinking) {
              final content = event.content ?? '';
              var thinkingContent = state.thinkingContent + content;

              // Filter out search results context if it leaked into thinking
              // This handles cases where the model echoes the context or it leaks from the server
              thinkingContent = thinkingContent
                  .replaceAll(
                    RegExp(
                      r'\[WEB SEARCH RESULTS\].*?\[END WEB SEARCH RESULTS\]',
                      dotAll: true,
                    ),
                    '',
                  )
                  .trim();

              // Heuristic to trigger Premium Search UI from Middleware stream
              bool isAnalyzing = state.isAnalyzingIntent;
              bool isSearching = state.isSearchingWeb;
              String statusMsg = state.searchStatusMessage;

              if (content.contains('Analyzing intent') ||
                  content.contains('Checking if search')) {
                isAnalyzing = true;
                isSearching = false;
                statusMsg = 'Analyzing intent...';
              } else if (content.contains('Searching for') ||
                  content.contains('Searching the web')) {
                isAnalyzing = false;
                isSearching = true;
                // Extract query if possible, or just use generic
                statusMsg = content.replaceAll('Thinking: ', '').trim();
              } else if (content.contains('Found') ||
                  content.contains('results')) {
                statusMsg = content.replaceAll('Thinking: ', '').trim();
              } else if (content.trim().isNotEmpty && content.length > 5) {
                // If we receive other substantial thinking content, assume we moved to generation phase
                // and turn off the special search/analysis UI
                isAnalyzing = false;
                isSearching = false;
              }

              // Trigger subtle haptic for thinking phase transitions
              if (!state.isThinking) {
                _hapticsHelper.triggerThinkingPulse();
              }

              state = state.copyWith(
                isThinking: true,
                thinkingContent: thinkingContent,
                isAnalyzingIntent: isAnalyzing,
                isSearchingWeb: isSearching,
                searchStatusMessage: statusMsg,
              );
            } else if (event.isSearchResults) {
              // Handle structured search results from middleware
              final results = event.metadata?['results'] ?? [];

              if (results is List && results.isNotEmpty) {
                state = state.copyWith(
                  lastSearchMetadata: {
                    'query': event.metadata?['query'] ?? 'Search Query',
                    'results':
                        results, // This is already a List<dynamic> (Maps) from JSON
                  },
                  searchStatusMessage: 'Found ${results.length} results',
                  isSearchingWeb: false, // Stop spinner
                );
              } else {
                Log.w(
                  'Received search_results but list is empty or invalid: $results',
                );
              }
            } else if (event.isContent) {
              // Trigger haptic feedback for streaming content (typing feel)
              // Pass content for punctuation-aware haptics
              _hapticsHelper.triggerStreamingHaptic(content: event.content);

              state = state.copyWith(
                isThinking: false,
                isAnalyzingIntent:
                    false, // Turn off search UI when content starts
                isSearchingWeb: false,
                streamingContent:
                    state.streamingContent + (event.content ?? ''),
              );
            } else if (event.isDone) {
              // Trigger completion haptic for satisfying "done" feel
              _hapticsHelper.triggerStreamingComplete();
              _finalizeStreamingMessage();
              completer.complete();
            } else if (event.isError) {
              state = state.copyWith(
                isStreaming: false,
                isLoading: false,
                error: event.errorMessage,
              );
              completer.complete();
            }
          },
          onError: (e) {
            state = state.copyWith(
              isStreaming: false,
              isLoading: false,
              error: e.toString(),
            );
            completer.complete();
          },
          onDone: () {
            if (!completer.isCompleted) {
              _finalizeStreamingMessage();
              completer.complete();
            }
          },
        );

    await completer.future;
  }

  void _finalizeStreamingMessage() {
    if (state.streamingContent.isEmpty) return;

    final aiMessage = ChatMessage(
      text: state.streamingContent,
      isUser: false,
      timestamp: DateTime.now(),
      thinkingContent: state.thinkingContent.isNotEmpty
          ? state.thinkingContent
          : null,
      searchMetadata: state.lastSearchMetadata,
    );

    state = state.copyWith(
      messages: [...state.messages, aiMessage],
      isStreaming: false,
      streamingContent: '',
      thinkingContent: '',
      isThinking: false,
      clearLastSearchMetadata: true, // Clear search metadata after using it
    );

    _saveAiMessage(aiMessage);
  }

  Future<void> _sendNonStreamingMessage(
    String contextText,
    List<String> attachmentPaths,
  ) async {
    String response;

    final systemPrompt = _settingsStorage.getSystemPrompt();
    final history = state.messages.length > 1
        ? state.messages.sublist(0, state.messages.length - 1)
        : <ChatMessage>[];

    response = await _repository.generateText(
      contextText,
      systemPrompt: systemPrompt,
      history: history,
    );

    await _finalizeMessage(response);
  }

  Future<void> _finalizeMessage(String response) async {
    final aiMessage = ChatMessage(
      text: response,
      isUser: false,
      timestamp: DateTime.now(),
      searchMetadata: state.lastSearchMetadata,
    );

    state = state.copyWith(
      messages: [...state.messages, aiMessage],
      isLoading: false,
      clearLastSearchMetadata: true, // Clear search metadata after using it
    );

    await _saveAiMessage(aiMessage);
  }

  Future<void> _saveAiMessage(ChatMessage aiMessage) async {
    if (!state.isPrivateMode) {
      await _historyStorage.saveMessage(aiMessage.toMap());

      final messageMaps = state.messages.map((m) => m.toMap()).toList();
      if (state.currentSessionId != null) {
        await _archiveStorage.updateSession(
          sessionId: state.currentSessionId!,
          messages: messageMaps,
        );
      } else {
        final sessionId = await _archiveStorage.archiveSession(
          messages: messageMaps,
        );
        state = state.copyWith(currentSessionId: sessionId);
      }
    }
  }

  Future<void> clearHistory() async {
    await _historyStorage.clearHistory();
    state = state.copyWith(messages: []);
  }

  Future<void> loadArchivedSession(String sessionId) async {
    final session = _archiveStorage.getSessionById(sessionId);
    if (session == null) {
      Log.e('Session not found: $sessionId');
      return;
    }

    if (state.messages.isNotEmpty && !state.isPrivateMode) {
      try {
        final messageMaps = state.messages.map((m) => m.toMap()).toList();
        if (state.currentSessionId != null) {
          await _archiveStorage.updateSession(
            sessionId: state.currentSessionId!,
            messages: messageMaps,
          );
        } else {
          await _archiveStorage.archiveSession(messages: messageMaps);
        }
      } catch (e) {
        Log.e('Failed to archive current session', e);
      }
    }

    final messages = session.messages
        .map((m) => ChatMessage.fromMap(m))
        .toList();

    await _historyStorage.clearHistory();
    for (final msg in messages) {
      await _historyStorage.saveMessage(msg.toMap());
    }

    state = state.copyWith(
      messages: messages,
      isPrivateMode: false,
      error: null,
      currentSessionId: session.id, // Track the loaded session ID
    );
    Log.storage('Loaded session: ${session.title}');
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(() {
  return ChatController();
});
