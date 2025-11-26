import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/connectivity_service.dart';
import '../../../core/services/document_service.dart';
import '../../../core/services/vision_service.dart';
import '../../../core/storage/chat_archive_storage.dart';
import '../../../core/storage/chat_history_storage.dart';
import '../../../core/storage/config_storage.dart';
import '../../settings/data/settings_storage.dart';
import '../../../core/utils/logger.dart';
import '../../../core/constants/app_constants.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_message.dart';
import '../utils/file_type_helper.dart';
import '../utils/mock_responses.dart';
import 'state/chat_state.dart';

class ChatController extends Notifier<ChatState> {
  late final ChatRepository _repository;
  late final ChatHistoryStorage _historyStorage;
  late final ChatArchiveStorage _archiveStorage;
  late final ConnectivityService _connectivityService;
  late final ConfigStorage _configStorage;
  late final SettingsStorage _settingsStorage;
  late final VisionService _visionService;
  late final DocumentService _documentService;

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
      String response;

      // 🧪 In test mode, use mock responses
      if (TestConfig.enabled) {
        await Future.delayed(
          const Duration(seconds: 2),
        ); // Simulate network delay
        response = MockResponses.getMockResponse(text, state.messages.length);
      } else {
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
          contextText =
              'Document content:\n$docContent\n\nUser question: $text';
        }

        // Check for image attachments
        final imageAttachments = attachmentPaths
            .where((path) => FileTypeHelper.isImageFile(path))
            .toList();

        // Only check connectivity if not local and not using edge vision
        if (!isLocal &&
            !(imageAttachments.isNotEmpty && visionMode == 'edge')) {
          final hasInternet = await _connectivityService.hasInternetConnection;
          if (!hasInternet) {
            throw Exception(
              'No internet connection. Cloud mode requires an active connection.',
            );
          }
        }

        if (imageAttachments.isNotEmpty) {
          // Use vision service for image analysis
          response = await _visionService.analyzeImage(
            imageAttachments.first,
            text.isEmpty ? 'Describe this image' : text,
          );
        } else {
          // Text-only: use chat generation
          final systemPrompt = _settingsStorage.getSystemPrompt();

          // Get conversation history (exclude current message - it's passed as prompt)
          final history = state.messages.length > 1
              ? state.messages.sublist(0, state.messages.length - 1)
              : <ChatMessage>[];

          response = await _repository.generateText(
            contextText,
            systemPrompt: systemPrompt,
            history: history,
          );
        }
      }

      final aiMessage = ChatMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isLoading: false,
      );

      // Only save to history if not in private mode
      if (!state.isPrivateMode) {
        await _historyStorage.saveMessage(aiMessage.toMap());

        // Auto-archive the session so it appears in history immediately
        final messageMaps = state.messages.map((m) => m.toMap()).toList();
        if (state.currentSessionId != null) {
          // Update existing session
          await _archiveStorage.updateSession(
            sessionId: state.currentSessionId!,
            messages: messageMaps,
          );
        } else {
          // Create new archive session and track its ID
          final sessionId = await _archiveStorage.archiveSession(
            messages: messageMaps,
          );
          state = state.copyWith(currentSessionId: sessionId);
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
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
