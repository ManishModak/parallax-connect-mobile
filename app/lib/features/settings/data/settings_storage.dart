import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/interfaces/haptics_settings.dart';
import '../../../global/providers.dart';

class SettingsStorage implements HapticsSettings {
  static const _keyHapticsLevel = 'settings_haptics_level';
  static const _keyVisionPipelineMode = 'settings_vision_pipeline_mode';
  static const _keySmartContextEnabled = 'settings_smart_context_enabled';
  static const _keyMaxContextTokens = 'settings_max_context_tokens';
  static const _keySystemPrompt = 'settings_system_prompt';
  static const _keyResponseStyle = 'settings_response_style';
  static const _keyStreamingEnabled = 'settings_streaming_enabled';
  static const _keyShowThinking = 'settings_show_thinking';

  final SharedPreferences _prefs;

  SettingsStorage(this._prefs);

  // Haptics Level
  // Values: 'none', 'min', 'max'
  // - none: No haptic feedback
  // - min: Light feedback on button taps
  // - max: min + typing feel during streaming responses
  Future<void> setHapticsLevel(String level) async {
    await _prefs.setString(_keyHapticsLevel, level);
  }

  @override
  String getHapticsLevel() {
    return _prefs.getString(_keyHapticsLevel) ??
        'max'; // Default to max for best UX
  }

  // Vision Pipeline Mode
  // Values: 'auto' (recommended), 'edge' (on-device ML Kit), 'server', 'multimodal'
  Future<void> setVisionPipelineMode(String mode) async {
    await _prefs.setString(_keyVisionPipelineMode, mode);
  }

  /// Get vision pipeline mode
  /// Returns 'auto' (default), 'edge' for privacy fallback, 'server', or 'multimodal'
  String getVisionPipelineMode() {
    return _prefs.getString(_keyVisionPipelineMode) ?? 'auto';
  }

  // Smart Context Window
  // Controls whether large documents are chunked automatically before sending to the server
  Future<void> setSmartContextEnabled(bool enabled) async {
    await _prefs.setBool(_keySmartContextEnabled, enabled);
  }

  /// Get smart context enabled
  /// Returns true when PDF/document ingestion should chunk automatically
  bool getSmartContextEnabled() {
    return _prefs.getBool(_keySmartContextEnabled) ?? true;
  }

  // Max Context Injection
  // Limits how many tokens from a document can be sent to the Parallax server at once
  Future<void> setMaxContextTokens(int tokens) async {
    await _prefs.setInt(_keyMaxContextTokens, tokens);
  }

  /// Get max context tokens
  /// Used by DocumentService to cap each request payload
  int getMaxContextTokens() {
    return _prefs.getInt(_keyMaxContextTokens) ?? 4096;
  }

  // System Prompt
  Future<void> setSystemPrompt(String prompt) async {
    await _prefs.setString(_keySystemPrompt, prompt);
  }

  String getSystemPrompt() {
    return _prefs.getString(_keySystemPrompt) ?? '';
  }

  // Response Style
  // Values: 'Concise', 'Formal', 'Casual', 'Detailed', 'Humorous', 'Neutral', 'Custom'
  Future<void> setResponseStyle(String style) async {
    await _prefs.setString(_keyResponseStyle, style);
  }

  String getResponseStyle() {
    return _prefs.getString(_keyResponseStyle) ?? 'Neutral';
  }

  // Streaming Enabled
  // Controls whether responses are streamed token-by-token
  Future<void> setStreamingEnabled(bool enabled) async {
    await _prefs.setBool(_keyStreamingEnabled, enabled);
  }

  /// Get streaming enabled
  /// Returns true when responses should stream in real-time
  bool getStreamingEnabled() {
    return _prefs.getBool(_keyStreamingEnabled) ?? true;
  }

  // Show Thinking
  // Controls whether model's thinking/reasoning is displayed
  Future<void> setShowThinking(bool show) async {
    await _prefs.setBool(_keyShowThinking, show);
  }

  /// Get show thinking
  /// Returns true when model's thinking process should be visible
  bool getShowThinking() {
    return _prefs.getBool(_keyShowThinking) ?? true;
  }

  // Web Search Settings
  static const _keyWebSearchEnabled = 'settings_web_search_enabled';
  static const _keyWebSearchProvider = 'settings_web_search_provider';
  static const _keyBraveSearchApiKey = 'settings_brave_search_api_key';

  Future<void> setWebSearchEnabled(bool enabled) async {
    await _prefs.setBool(_keyWebSearchEnabled, enabled);
  }

  bool getWebSearchEnabled() {
    return _prefs.getBool(_keyWebSearchEnabled) ?? true; // Default enabled
  }

  Future<void> setWebSearchProvider(String provider) async {
    await _prefs.setString(_keyWebSearchProvider, provider);
  }

  String getWebSearchProvider() {
    return _prefs.getString(_keyWebSearchProvider) ?? 'duckduckgo';
  }

  Future<void> setBraveSearchApiKey(String apiKey) async {
    await _prefs.setString(_keyBraveSearchApiKey, apiKey);
  }

  String? getBraveSearchApiKey() {
    return _prefs.getString(_keyBraveSearchApiKey);
  }

  static const _keyWebSearchDepth = 'settings_web_search_depth';

  Future<void> setWebSearchDepth(String depth) async {
    await _prefs.setString(_keyWebSearchDepth, depth);
  }

  String getWebSearchDepth() {
    return _prefs.getString(_keyWebSearchDepth) ?? 'normal'; // Default normal
  }

  static const _keySmartSearchEnabled = 'settings_smart_search_enabled';
  static const _keyWebSearchExecutionMode =
      'settings_web_search_execution_mode';

  Future<void> setSmartSearchEnabled(bool enabled) async {
    await _prefs.setBool(_keySmartSearchEnabled, enabled);
  }

  bool getSmartSearchEnabled() {
    return _prefs.getBool(_keySmartSearchEnabled) ?? true;
  }

  Future<void> setWebSearchExecutionMode(String mode) async {
    await _prefs.setString(_keyWebSearchExecutionMode, mode);
  }

  String getWebSearchExecutionMode() {
    return _prefs.getString(_keyWebSearchExecutionMode) ??
        'middleware'; // mobile, middleware, parallax
  }

  // Document Processing Mode
  // Values: 'mobile' (on-device extraction), 'server' (middleware extraction)
  static const _keyDocProcessingMode = 'settings_doc_processing_mode';

  Future<void> setDocProcessingMode(String mode) async {
    await _prefs.setString(_keyDocProcessingMode, mode);
  }

  /// Get document processing mode
  /// Returns 'server' (default), 'mobile' for privacy
  String getDocProcessingMode() {
    return _prefs.getString(_keyDocProcessingMode) ?? 'server';
  }

  // Clear all settings (reset to defaults)
  Future<void> clearSettings() async {
    await _prefs.remove(_keyHapticsLevel);
    await _prefs.remove(_keyVisionPipelineMode);
    await _prefs.remove(_keySmartContextEnabled);
    await _prefs.remove(_keyMaxContextTokens);
    await _prefs.remove(_keySystemPrompt);
    await _prefs.remove(_keyResponseStyle);
    await _prefs.remove(_keyStreamingEnabled);
    await _prefs.remove(_keyShowThinking);
  }
}

final settingsStorageProvider = Provider<SettingsStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsStorage(prefs);
});
