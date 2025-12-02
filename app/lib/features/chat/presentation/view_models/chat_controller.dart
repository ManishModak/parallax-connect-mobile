import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/file_type_helper.dart';
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

    final messages = _historyStorage.getHistory();
    return ChatState(
      messages: messages.map((m) => ChatMessage.fromMap(m)).toList(),
    );
  }

  void startNewChat() {
    state = state.copyWith(
      messages: [],
      error: null,
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
    state = state.copyWith(editingMessage: null);
  }

  Future<void> submitEdit(String newText) async {
    final message = state.editingMessage;
    if (message == null) return;

    // Clear editing state
    state = state.copyWith(editingMessage: null);

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
      error: null,
    );

    // Only save to history if not in private mode
    if (!state.isPrivateMode) {
      await _historyStorage.saveMessage(userMessage.toMap());
    }

    try {
      // Check if streaming is enabled
      final isStreamingEnabled = _settingsStorage.getStreamingEnabled();

      // Check connectivity for cloud mode (not needed for edge vision)
      final isLocal = _configStorage.getIsLocal();
      final visionMode = _settingsStorage.getVisionPipelineMode();

      final docAttachments = attachmentPaths
          .where(
            (path) =>
                FileTypeHelper.isPdfFile(path) ||
                FileTypeHelper.isTextFile(path),
          )
          .toList();
      String contextText = text;
      if (docAttachments.isNotEmpty) {
        final docContent = await _documentService.extractText(
          docAttachments.first,
        );
        contextText = 'Document content:\n$docContent\n\nUser question: $text';
      }

      // Smart Web Search Logic
      if (state.webSearchMode != 'off' && text.isNotEmpty) {
        final executionMode = _settingsStorage.getWebSearchExecutionMode();

        // Only Mobile mode does the 2-step flow on the client
        if (executionMode == 'mobile') {
          // Step 1: Intent Analysis (Generic Thinking UI)
          state = state.copyWith(
            isAnalyzingIntent: true,
            isSearchingWeb: false,
            searchStatusMessage: 'Analyzing intent...',
            // Ensure no snippets are shown yet
            isThinking: false,
          );

          try {
            // Get history for context
            final history = state.messages
                .where((m) => !m.isUser)
                .take(4)
                .map(
                  (m) => {
                    'role': m.isUser ? 'user' : 'assistant',
                    'content': m.text,
                  },
                )
                .toList();

            final searchResult = await _smartSearchService.smartSearch(
              text,
              history,
              depth: state.webSearchMode,
            );

            // Step 2: Action (Search or Skip)
            if (searchResult.needsSearch) {
              state = state.copyWith(
                isAnalyzingIntent: false,
                isSearchingWeb: true,
                currentSearchQuery: searchResult.searchQuery,
                searchStatusMessage:
                    'Searching for "${searchResult.searchQuery}"...',
              );

              // Wait a bit to show the UI (optional, but good for UX)
              await Future.delayed(const Duration(milliseconds: 500));

              if (searchResult.results.isNotEmpty) {
                contextText = '${searchResult.summary}\n\nUser Question: $text';
                state = state.copyWith(
                  searchStatusMessage:
                      'Found ${searchResult.results.length} results',
                  lastSearchMetadata: {
                    'query': searchResult.searchQuery,
                    'results': searchResult.results,
                    'summary': searchResult.summary,
                  },
                );
              } else {
                state = state.copyWith(searchStatusMessage: 'No results found');
              }
            } else {
              // No search needed
              state = state.copyWith(
                isAnalyzingIntent: false,
                searchStatusMessage: 'No search needed',
              );
            }
          } catch (e) {
            Log.e('Smart search failed', e);
          } finally {
            // Clear search flags before generation starts
            state = state.copyWith(
              isAnalyzingIntent: false,
              isSearchingWeb: false,
            );
          }
        } else {
          // Middleware/Parallax Mode: Just set analyzing flag and let stream events drive UI
          // We don't do the 2-step flow here, the server does.
          // But we want to show "Analyzing" initially.
          state = state.copyWith(
            isAnalyzingIntent: true,
            searchStatusMessage: 'Analyzing intent...',
          );
        }
      }

      // Check for image attachments
      final imageAttachments = attachmentPaths
          .where((path) => FileTypeHelper.isImageFile(path))
          .toList();

      // Only check connectivity if not local and not using edge vision
      if (!isLocal && !(imageAttachments.isNotEmpty && visionMode == 'edge')) {
        final hasInternet = await _connectivityService.hasInternetConnection;
        if (!hasInternet) {
          throw Exception(
            'No internet connection. Cloud mode requires an active connection.',
          );
        }
      }

      if (imageAttachments.isNotEmpty) {
        // Use vision service for image analysis (non-streaming)
        final response = await _visionService.analyzeImage(
          imageAttachments.first,
          text.isEmpty ? 'Describe this image' : text,
        );
        await _finalizeMessage(response);
      } else if (isStreamingEnabled) {
        // Use streaming for text-only chat
        // Step 3: Generation (Snippet Thinking -> Content)
        await _sendStreamingMessage(contextText);
      } else {
        // Use non-streaming for text-only chat
        await _sendNonStreamingMessage(contextText, attachmentPaths);
      }
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

  Future<void> _sendStreamingMessage(String contextText) async {
    final systemPrompt = _settingsStorage.getSystemPrompt();
    final history = state.messages.length > 1
        ? state.messages.sublist(0, state.messages.length - 1)
        : <ChatMessage>[];

    state = state.copyWith(
      isLoading: false,
      isStreaming: true,
      streamingContent: '',
      thinkingContent: '',
      isThinking: false,
    );

    final completer = Completer<void>();

    _repository
        .generateTextStream(
          contextText,
          systemPrompt: systemPrompt,
          history: history,
          webSearchEnabled: state.webSearchMode != 'off',
          webSearchDepth: state.webSearchMode,
        )
        .listen(
          (event) {
            if (event.isThinking) {
              final content = event.content ?? '';
              final thinkingContent = state.thinkingContent + content;

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
                    'results': results,
                  },
                  searchStatusMessage: 'Found ${results.length} results',
                  isSearchingWeb: false, // Stop spinner
                );
              }
            } else if (event.isContent) {
              // Trigger haptic feedback for streaming content (typing feel)
              _hapticsHelper.triggerStreamingHaptic();

              state = state.copyWith(
                isThinking: false,
                isAnalyzingIntent:
                    false, // Turn off search UI when content starts
                isSearchingWeb: false,
                streamingContent:
                    state.streamingContent + (event.content ?? ''),
              );
            } else if (event.isDone) {
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
      lastSearchMetadata: null, // Clear search metadata after using it
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
      lastSearchMetadata: null, // Clear search metadata after using it
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
