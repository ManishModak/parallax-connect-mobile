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
  final String webSearchDepth;

  // Smart Search
  final bool isSmartSearchEnabled;
  final String webSearchExecutionMode; // mobile, middleware, parallax

  // Document Processing
  final String docProcessingMode; // mobile, server

  const SettingsState({
    this.hapticsLevel = 'max',
    this.visionPipelineMode = 'edge',
    this.isSmartContextEnabled = true,
    this.maxContextTokens = 4096,
    this.systemPrompt = '',
    this.responseStyle = 'Neutral',
    this.isStreamingEnabled = true,
    this.showThinking = true,
    this.isWebSearchEnabled = true,
    this.webSearchProvider = 'duckduckgo',
    this.braveSearchApiKey,
    this.webSearchDepth = 'normal',
    this.isSmartSearchEnabled = true,
    this.webSearchExecutionMode = 'mobile',
    this.docProcessingMode = 'server',
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
    String? webSearchDepth,
    bool? isSmartSearchEnabled,
    String? webSearchExecutionMode,
    String? docProcessingMode,
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
      webSearchDepth: webSearchDepth ?? this.webSearchDepth,
      isSmartSearchEnabled: isSmartSearchEnabled ?? this.isSmartSearchEnabled,
      webSearchExecutionMode:
          webSearchExecutionMode ?? this.webSearchExecutionMode,
      docProcessingMode: docProcessingMode ?? this.docProcessingMode,
    );
  }
}
