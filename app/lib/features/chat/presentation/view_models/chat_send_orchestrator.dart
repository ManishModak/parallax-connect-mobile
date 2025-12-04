import '../../utils/file_type_helper.dart';
import '../../../../core/services/system/connectivity_service.dart';
import '../../../../core/services/utilities/document_service.dart';
import '../../../../core/services/ai/smart_search_service.dart';
import '../../../../core/services/ai/vision_service.dart';
import '../../../../core/services/storage/config_storage.dart';
import '../../../settings/data/settings_storage.dart';
import '../../../../core/utils/logger.dart';
import '../state/chat_state.dart';

/// Coordinates the complex send flow for chat:
/// - attachment & document context building
/// - optional smart web search pre-step
/// - connectivity checks
/// - choosing between vision, streaming, and non-streaming paths
///
/// This keeps `ChatController` slim and focused on state wiring.
class ChatSendOrchestrator {
  final SettingsStorage _settingsStorage;
  final ConfigStorage _configStorage;
  final VisionService _visionService;
  final ConnectivityService _connectivityService;
  final DocumentService _documentService;
  final SmartSearchService _smartSearchService;

  ChatSendOrchestrator({
    required SettingsStorage settingsStorage,
    required ConfigStorage configStorage,
    required VisionService visionService,
    required ConnectivityService connectivityService,
    required DocumentService documentService,
    required SmartSearchService smartSearchService,
  })  : _settingsStorage = settingsStorage,
        _configStorage = configStorage,
        _visionService = visionService,
        _connectivityService = connectivityService,
        _documentService = documentService,
        _smartSearchService = smartSearchService;

  Future<void> send({
    required String text,
    required List<String> attachmentPaths,
    required ChatState initialState,
    required void Function(ChatState) setState,
    required Future<void> Function(
      String contextText, {
      bool disableWebSearch,
    })
        sendStreaming,
    required Future<void> Function(
      String contextText,
      List<String> attachmentPaths,
    )
        sendNonStreaming,
    required Future<void> Function(String response) finalizeMessage,
  }) async {
    // Local copy of state so we can keep using the latest snapshot after
    // each copyWith + setState.
    var state = initialState;

    ChatState updateState(ChatState Function(ChatState) updater) {
      final updated = updater(state);
      setState(updated);
      state = updated;
      return updated;
    }

    // 1) Streaming/vision mode & connectivity flags
    final isStreamingEnabled = _settingsStorage.getStreamingEnabled();
    final isLocal = _configStorage.getIsLocal();
    final visionMode = _settingsStorage.getVisionPipelineMode();

    // 2) Build context from document attachments (PDF/text)
    final docAttachments = attachmentPaths
        .where(
          (path) =>
              FileTypeHelper.isPdfFile(path) || FileTypeHelper.isTextFile(path),
        )
        .toList();

    String contextText = text;
    if (docAttachments.isNotEmpty) {
      final docContent = await _documentService.extractText(docAttachments.first);
      contextText = 'Document content:\n$docContent\n\nUser question: $text';
    }

    // 3) Optional smart web search (client-side mobile mode)
    if (state.webSearchMode != 'off' && text.isNotEmpty) {
      final executionMode = _settingsStorage.getWebSearchExecutionMode();

      // Only Mobile mode does the 2-step flow on the client
      if (executionMode == 'mobile') {
        // Step 1: Intent Analysis (Generic Thinking UI)
        updateState(
          (s) => s.copyWith(
            isAnalyzingIntent: true,
            isSearchingWeb: false,
            searchStatusMessage: 'Analyzing intent...',
            // Ensure no snippets are shown yet
            isThinking: false,
          ),
        );

        try {
          // Get history for context (only assistant messages, last 4)
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
            updateState(
              (s) => s.copyWith(
                isAnalyzingIntent: false,
                isSearchingWeb: true,
                currentSearchQuery: searchResult.searchQuery,
                searchStatusMessage:
                    'Searching for "${searchResult.searchQuery}"...',
              ),
            );

            // Wait a bit to show the UI (optional, but good for UX)
            await Future.delayed(const Duration(milliseconds: 500));

            if (searchResult.results.isNotEmpty) {
              contextText = '${searchResult.summary}\n\nUser Question: $text';
              updateState(
                (s) => s.copyWith(
                  searchStatusMessage:
                      'Found ${searchResult.results.length} results',
                  lastSearchMetadata: {
                    'query': searchResult.searchQuery,
                    'results': searchResult.results
                        .map(
                          (r) => {
                            'title': r.title,
                            'url': r.url,
                            'snippet': r.snippet,
                            'content': r.content,
                          },
                        )
                        .toList(),
                    'summary': searchResult.summary,
                  },
                ),
              );
            } else {
              updateState(
                (s) => s.copyWith(
                  searchStatusMessage: 'No results found',
                ),
              );
            }
          } else {
            // No search needed
            updateState(
              (s) => s.copyWith(
                isAnalyzingIntent: false,
                searchStatusMessage: 'No search needed',
              ),
            );
          }
        } catch (e) {
          Log.e('Smart search failed', e);
        } finally {
          // Clear search flags before generation starts
          updateState(
            (s) => s.copyWith(
              isAnalyzingIntent: false,
              isSearchingWeb: false,
            ),
          );
        }
      } else {
        // Middleware/Parallax Mode: Just set analyzing flag and let stream events
        // drive UI. We don't do the 2-step flow here, the server does.
        // But we want to show "Analyzing" initially.
        updateState(
          (s) => s.copyWith(
            isAnalyzingIntent: true,
            searchStatusMessage: 'Analyzing intent...',
          ),
        );
      }
    }

    // 4) Connectivity & attachment routing (vision vs text)

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
      await finalizeMessage(response);
      return;
    }

    if (isStreamingEnabled) {
      // Use streaming for text-only chat
      // Step 3: Generation (Snippet Thinking -> Content)
      final executionMode = _settingsStorage.getWebSearchExecutionMode();
      await sendStreaming(
        contextText,
        disableWebSearch: executionMode == 'mobile',
      );
    } else {
      // Use non-streaming for text-only chat
      await sendNonStreaming(contextText, attachmentPaths);
    }
  }
}


