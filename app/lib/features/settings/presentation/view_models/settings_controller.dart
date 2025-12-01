import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/chat_history_storage.dart';
import '../../data/settings_storage.dart';
import '../state/settings_state.dart';

class SettingsController extends Notifier<SettingsState> {
  late final SettingsStorage _settingsStorage;
  late final ChatHistoryStorage _chatHistoryStorage;

  @override
  SettingsState build() {
    _settingsStorage = ref.watch(settingsStorageProvider);
    _chatHistoryStorage = ref.watch(chatHistoryStorageProvider);

    return SettingsState(
      hapticsLevel: _settingsStorage.getHapticsLevel(),
      visionPipelineMode: _settingsStorage.getVisionPipelineMode(),
      isSmartContextEnabled: _settingsStorage.getSmartContextEnabled(),
      maxContextTokens: _settingsStorage.getMaxContextTokens(),
      systemPrompt: _settingsStorage.getSystemPrompt(),
      responseStyle: _settingsStorage.getResponseStyle(),
      isStreamingEnabled: _settingsStorage.getStreamingEnabled(),
      showThinking: _settingsStorage.getShowThinking(),
      isWebSearchEnabled: _settingsStorage.getWebSearchEnabled(),
      webSearchProvider: _settingsStorage.getWebSearchProvider(),
      braveSearchApiKey: _settingsStorage.getBraveSearchApiKey(),
      webSearchDepth: _settingsStorage.getWebSearchDepth(),
      isSmartSearchEnabled: _settingsStorage.getSmartSearchEnabled(),
      webSearchExecutionMode: _settingsStorage.getWebSearchExecutionMode(),
    );
  }

  Future<void> setHapticsLevel(String level) async {
    await _settingsStorage.setHapticsLevel(level);
    state = state.copyWith(hapticsLevel: level);
  }

  Future<void> setVisionPipelineMode(String mode) async {
    await _settingsStorage.setVisionPipelineMode(mode);
    state = state.copyWith(visionPipelineMode: mode);
  }

  Future<void> toggleSmartContext(bool enabled) async {
    await _settingsStorage.setSmartContextEnabled(enabled);
    state = state.copyWith(isSmartContextEnabled: enabled);
  }

  Future<void> setMaxContextTokens(int tokens) async {
    await _settingsStorage.setMaxContextTokens(tokens);
    state = state.copyWith(maxContextTokens: tokens);
  }

  Future<void> setSystemPrompt(String prompt) async {
    await _settingsStorage.setSystemPrompt(prompt);
    // If the prompt doesn't match the current style's preset, switch to Custom
    // This logic might be better handled in the UI or by checking against known presets
    if (state.responseStyle != 'Custom' &&
        _getPresetPrompt(state.responseStyle) != prompt) {
      await setResponseStyle('Custom');
    }
    state = state.copyWith(systemPrompt: prompt);
  }

  Future<void> setResponseStyle(String style) async {
    await _settingsStorage.setResponseStyle(style);

    // If it's a preset, update the system prompt text
    if (style != 'Custom') {
      final presetPrompt = _getPresetPrompt(style);
      await _settingsStorage.setSystemPrompt(presetPrompt);
      state = state.copyWith(responseStyle: style, systemPrompt: presetPrompt);
    } else {
      state = state.copyWith(responseStyle: style);
    }
  }

  String _getPresetPrompt(String style) {
    switch (style) {
      case 'Concise':
        return 'Keep the response brief and direct. Use as few words as necessary to clearly convey the message. Avoid unnecessary elaboration.';
      case 'Formal':
        return 'Maintain a professional and formal tone. Use complete sentences and avoid slang or colloquialisms.';
      case 'Casual':
        return 'Keep the tone conversational and friendly. Feel free to use idioms and a more relaxed style.';
      case 'Detailed':
        return 'Provide comprehensive and detailed explanations. Cover all aspects of the topic thoroughly.';
      case 'Humorous':
        return 'Inject humor and wit into the responses where appropriate. Keep the tone lighthearted.';
      case 'Neutral':
        return '';
      default:
        return '';
    }
  }

  Future<void> setStreamingEnabled(bool enabled) async {
    await _settingsStorage.setStreamingEnabled(enabled);
    state = state.copyWith(isStreamingEnabled: enabled);
  }

  Future<void> setShowThinking(bool show) async {
    await _settingsStorage.setShowThinking(show);
    state = state.copyWith(showThinking: show);
  }

  Future<void> clearAllData() async {
    await _chatHistoryStorage.clearHistory();
    await _settingsStorage.clearSettings();

    // Refresh state from storage (which should be defaults now)
    state = SettingsState(
      hapticsLevel: _settingsStorage.getHapticsLevel(),
      visionPipelineMode: _settingsStorage.getVisionPipelineMode(),
      isSmartContextEnabled: _settingsStorage.getSmartContextEnabled(),
      maxContextTokens: _settingsStorage.getMaxContextTokens(),
      systemPrompt: _settingsStorage.getSystemPrompt(),
      responseStyle: _settingsStorage.getResponseStyle(),
      isStreamingEnabled: _settingsStorage.getStreamingEnabled(),
      showThinking: _settingsStorage.getShowThinking(),
      isWebSearchEnabled: _settingsStorage.getWebSearchEnabled(),
      webSearchProvider: _settingsStorage.getWebSearchProvider(),
      braveSearchApiKey: _settingsStorage.getBraveSearchApiKey(),
      webSearchDepth: _settingsStorage.getWebSearchDepth(),
      isSmartSearchEnabled: _settingsStorage.getSmartSearchEnabled(),
      webSearchExecutionMode: _settingsStorage.getWebSearchExecutionMode(),
    );
  }

  Future<void> setWebSearchEnabled(bool enabled) async {
    await _settingsStorage.setWebSearchEnabled(enabled);
    state = state.copyWith(isWebSearchEnabled: enabled);
  }

  Future<void> setWebSearchProvider(String provider) async {
    await _settingsStorage.setWebSearchProvider(provider);
    state = state.copyWith(webSearchProvider: provider);
  }

  Future<void> setBraveSearchApiKey(String apiKey) async {
    await _settingsStorage.setBraveSearchApiKey(apiKey);
    state = state.copyWith(braveSearchApiKey: apiKey);
  }

  Future<void> setWebSearchDepth(String depth) async {
    await _settingsStorage.setWebSearchDepth(depth);
    state = state.copyWith(webSearchDepth: depth);
  }

  Future<void> setSmartSearchEnabled(bool enabled) async {
    await _settingsStorage.setSmartSearchEnabled(enabled);
    state = state.copyWith(isSmartSearchEnabled: enabled);
  }

  Future<void> setWebSearchExecutionMode(String mode) async {
    await _settingsStorage.setWebSearchExecutionMode(mode);
    state = state.copyWith(webSearchExecutionMode: mode);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(() {
      return SettingsController();
    });
