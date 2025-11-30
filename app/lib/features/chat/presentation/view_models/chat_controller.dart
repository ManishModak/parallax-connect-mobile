import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/document_service.dart';
import '../../../../core/services/vision_service.dart';
import '../../../../core/storage/chat_archive_storage.dart';
import '../../../../core/storage/chat_history_storage.dart';
import '../../../../core/storage/config_storage.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../../../settings/data/settings_storage.dart';
import '../../../../core/utils/logger.dart';
import '../../../../../app/constants/app_constants.dart';
import '../../../../core/services/web_search_service.dart';
import '../../data/chat_repository.dart';
import '../../data/models/chat_message.dart';
import '../../utils/file_type_helper.dart';
import '../../utils/mock_responses.dart';
import '../state/chat_state.dart';

class ChatController extends Notifier<ChatState> {
  late final ChatRepository _repository;
  late final ChatHistoryStorage _historyStorage;
  late final ChatArchiveStorage _archiveStorage;
  late final ConnectivityService _connectivityService;
  late final ConfigStorage _configStorage;
  late final SettingsStorage _settingsStorage;
  late final VisionService _visionService;
  late final DocumentService _documentService;
  late final HapticsHelper _hapticsHelper;
  late final WebSearchService _webSearchService;

  @override
  ChatState build() {
    _repository = ref.read(chatRepositoryProvider);
    _historyStorage = ref.read(chatHistoryStorageProvider);
    _archiveStorage = ref.read(chatArchiveStorageProvider);
    _connectivityService = ref.read(connectivityServiceProvider);
    _configStorage = ref.read(configStorageProvider);
    _settingsStorage = ref.read(settingsStorageProvider);
    _visionService = ref.read(visionServiceProvider);
    _documentService = ref.read(documentServiceProvider);
    _hapticsHelper = ref.read(hapticsHelperProvider);
    _webSearchService = ref.read(webSearchServiceProvider);

    // Load history and return initial state with messages
    final history = _historyStorage.getHistory();
    final messages = history.map((e) => ChatMessage.fromMap(e)).toList();

    return ChatState(messages: messages);
  }

  Future<void> startNewChat() async {
    // Archive current chat session before clearing
    // Only archive if there are messages and not in private mode
    if (state.messages.isNotEmpty && !state.isPrivateMode) {
      try {
        final messageMaps = state.messages.map((m) => m.toMap()).toList();

        // Always create a new session when starting new chat
        // Don't try to update - this prevents "session not found" errors
        await _archiveStorage.archiveSession(messages: messageMaps);
        Log.storage('Created new archived session');
      } catch (e) {
        Log.e('Failed to archive session', e);
        // Continue with clearing even if archiving fails
      }
    }

    await clearHistory();
    // Clear session ID for new chat
    state = state.copyWith(currentSessionId: null);
  }

  void togglePrivateMode() {
    final newMode = !state.isPrivateMode;
    state = state.copyWith(
      isPrivateMode: newMode,
      messages: newMode ? [] : state.messages, // Clear messages when enabling
      error: null,
    );
  }

  void disablePrivateMode() {
    state = state.copyWith(isPrivateMode: false, messages: [], error: null);
  }

  StreamSubscription<StreamEvent>? _streamSubscription;

  void cancelStreaming() {
    _streamSubscription?.cancel();
    _streamSubscription = null;

    // If we were streaming, finalize the message
    if (state.isStreaming && state.streamingContent.isNotEmpty) {
      final aiMessage = ChatMessage(
        text: state.streamingContent,
        isUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isStreaming: false,
        isLoading: false,
        streamingContent: '',
        thinkingContent: '',
        isThinking: false,
      );
    } else {
      state = state.copyWith(
        isStreaming: false,
        isLoading: false,
        streamingContent: '',
        thinkingContent: '',
        isThinking: false,
      );
    }
  }

  Future<void> editMessage(ChatMessage message, String newText) async {
    final index = state.messages.indexOf(message);
    if (index == -1) return;

    // Remove this message and all subsequent messages
    final newMessages = state.messages.sublist(0, index);
    state = state.copyWith(messages: newMessages);

    // Update history storage
    if (!state.isPrivateMode) {
      await _historyStorage.clearHistory();
      for (final msg in newMessages) {
        await _historyStorage.saveMessage(msg.toMap());
      }
    }

    // Send the new message
    await sendMessage(newText, attachmentPaths: message.attachmentPaths);
  }

  Future<void> retryMessage(ChatMessage message) async {
    final index = state.messages.indexOf(message);
    if (index == -1) return;

    // Remove all messages AFTER this one (the AI response)
    // We keep the user message for now, but sendMessage will add a NEW one.
    // So we should actually remove this one too if we want to "resend" it cleanly
    // OR we just remove the AI response and trigger generation again.
    // But sendMessage adds the user message to the state.
    // So we should remove this message and everything after it, then resend.

    final newMessages = state.messages.sublist(0, index);
    state = state.copyWith(messages: newMessages);

    // Update history storage
    if (!state.isPrivateMode) {
      await _historyStorage.clearHistory();
      for (final msg in newMessages) {
        await _historyStorage.saveMessage(msg.toMap());
      }
    }

    await sendMessage(message.text, attachmentPaths: message.attachmentPaths);
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

      // 🧪 In test mode, use mock responses (non-streaming)
      if (TestConfig.enabled) {
        await _sendNonStreamingMessage(text, attachmentPaths);
        return;
      }

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

      // Web Search Logic
      if (_settingsStorage.getWebSearchEnabled() && text.isNotEmpty) {
        state = state.copyWith(isSearching: true);
        try {
          final searchResults = await _webSearchService.search(text);
          if (searchResults.isNotEmpty) {
            contextText =
                'Web Search Results:\n$searchResults\n\nUser Question: $text';
          }
        } catch (e) {
          Log.e('Web search failed', e);
          // Continue without search results
        } finally {
          state = state.copyWith(isSearching: false);
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
        await _sendStreamingMessage(contextText);
      } else {
        // Use non-streaming for text-only chat
        await _sendNonStreamingMessage(contextText, attachmentPaths);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isStreaming: false,
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

    _streamSubscription = _repository
        .generateTextStream(
          contextText,
          systemPrompt: systemPrompt,
          history: history,
        )
        .listen(
          (event) {
            if (event.isThinking) {
              state = state.copyWith(
                isThinking: true,
                thinkingContent:
                    (state.thinkingContent + (event.content ?? '')),
              );
            } else if (event.isContent) {
              // Trigger haptic feedback for streaming content (typing feel)
              _hapticsHelper.triggerStreamingHaptic();

              state = state.copyWith(
                isThinking: false,
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
    );

    state = state.copyWith(
      messages: [...state.messages, aiMessage],
      isStreaming: false,
      streamingContent: '',
      thinkingContent: '',
      isThinking: false,
    );

    _saveAiMessage(aiMessage);
  }

  Future<void> _sendNonStreamingMessage(
    String contextText,
    List<String> attachmentPaths,
  ) async {
    String response;

    if (TestConfig.enabled) {
      await Future.delayed(const Duration(seconds: 2));
      response = MockResponses.getMockResponse(
        contextText,
        state.messages.length,
      );
    } else {
      final systemPrompt = _settingsStorage.getSystemPrompt();
      final history = state.messages.length > 1
          ? state.messages.sublist(0, state.messages.length - 1)
          : <ChatMessage>[];

      response = await _repository.generateText(
        contextText,
        systemPrompt: systemPrompt,
        history: history,
      );
    }

    await _finalizeMessage(response);
  }

  Future<void> _finalizeMessage(String response) async {
    final aiMessage = ChatMessage(
      text: response,
      isUser: false,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, aiMessage],
      isLoading: false,
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

