class SettingsState {
  final String hapticsLevel;
  final String visionPipelineMode;
  final bool isSmartContextEnabled;
  final int maxContextTokens;
  final String systemPrompt;
  final String responseStyle;
  final bool isStreamingEnabled;
  final bool showThinking;
  final bool isWebSearchEnabled;
  final String webSearchProvider;
  final String? braveSearchApiKey;
  final bool isDeepSearchEnabled;

  SettingsState({
    required this.hapticsLevel,
    required this.visionPipelineMode,
    required this.isSmartContextEnabled,
    required this.maxContextTokens,
    required this.systemPrompt,
    required this.responseStyle,
    this.isStreamingEnabled = true,
    this.showThinking = true,
    this.isWebSearchEnabled = true,
    this.webSearchProvider = 'duckduckgo',
    this.braveSearchApiKey,
    this.isDeepSearchEnabled = false,
  });

  SettingsState copyWith({
    String? hapticsLevel,
    String? visionPipelineMode,
    bool? isSmartContextEnabled,
    int? maxContextTokens,
    String? systemPrompt,
    String? responseStyle,
    bool? isStreamingEnabled,
    bool? showThinking,
    bool? isWebSearchEnabled,
    String? webSearchProvider,
    String? braveSearchApiKey,
    bool? isDeepSearchEnabled,
  }) {
    return SettingsState(
      hapticsLevel: hapticsLevel ?? this.hapticsLevel,
      visionPipelineMode: visionPipelineMode ?? this.visionPipelineMode,
      isSmartContextEnabled:
          isSmartContextEnabled ?? this.isSmartContextEnabled,
      maxContextTokens: maxContextTokens ?? this.maxContextTokens,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      responseStyle: responseStyle ?? this.responseStyle,
      isStreamingEnabled: isStreamingEnabled ?? this.isStreamingEnabled,
      showThinking: showThinking ?? this.showThinking,
      isWebSearchEnabled: isWebSearchEnabled ?? this.isWebSearchEnabled,
      webSearchProvider: webSearchProvider ?? this.webSearchProvider,
      braveSearchApiKey: braveSearchApiKey ?? this.braveSearchApiKey,
      isDeepSearchEnabled: isDeepSearchEnabled ?? this.isDeepSearchEnabled,
    );
  }
}
