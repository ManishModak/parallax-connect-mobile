import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics_helper.dart';
import '../../../core/storage/chat_archive_storage.dart';
import '../../../core/services/feature_flags_service.dart';
import '../../../core/services/server_capabilities_service.dart';
import '../../chat/presentation/chat_controller.dart';
import 'settings_controller.dart';
import 'widgets/about_card.dart';
import 'widgets/clear_history_confirmation_dialog.dart';
import 'widgets/context_slider.dart';
import 'widgets/feature_info_dialog.dart';
import 'widgets/feature_toggle_tile.dart';
import 'widgets/haptics_selector.dart';
import 'widgets/response_preference_section.dart';
import 'widgets/section_header.dart';
import 'widgets/smart_context_switch.dart';
import 'widgets/streaming_settings_section.dart';
import 'widgets/vision_option_tile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _systemPromptController;

  @override
  void initState() {
    super.initState();
    _systemPromptController = TextEditingController(
      text: ref.read(settingsControllerProvider).systemPrompt,
    );
    // Fetch server capabilities on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(featureFlagsProvider.notifier).refreshCapabilities();
    });
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    super.dispose();
  }

  Widget _buildFeatureCapabilitiesSection(HapticsHelper hapticsHelper) {
    final featureFlags = ref.watch(featureFlagsProvider);
    final capsAsync = ref.watch(serverCapabilitiesProvider);
    final featureFlagsNotifier = ref.read(featureFlagsProvider.notifier);
    final caps = capsAsync.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Feature Capabilities')),
            // Refresh button
            capsAsync.when(
              loading: () => const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => IconButton(
                icon: Icon(
                  LucideIcons.refreshCw,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: () {
                  hapticsHelper.triggerHaptics();
                  featureFlagsNotifier.refreshCapabilities();
                },
                tooltip: 'Retry fetching capabilities',
              ),
              data: (_) => IconButton(
                icon: Icon(
                  LucideIcons.refreshCw,
                  color: AppColors.secondary,
                  size: 20,
                ),
                onPressed: () {
                  hapticsHelper.triggerHaptics();
                  featureFlagsNotifier.refreshCapabilities();
                },
                tooltip: 'Refresh server capabilities',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Info banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.info, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  featureFlags.capabilitiesFetched
                      ? 'Tap on a feature to configure it. Features are disabled by default for safety.'
                      : 'Connect to your Parallax server to detect available features.',
                  style: GoogleFonts.inter(
                    color: AppColors.secondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Attachments toggle
        FeatureToggleTile(
          title: 'Attachments',
          badgeText: 'BETA',
          description: 'Send images and documents in chat.',
          status: featureFlags.attachments,
          onTap: () => _showAttachmentsDialog(
            hapticsHelper,
            featureFlags,
            featureFlagsNotifier,
            caps,
          ),
        ),
        const SizedBox(height: 12),
        // Multimodal Vision toggle
        FeatureToggleTile(
          title: 'Full Multimodal Vision',
          badgeText: 'EXPERIMENTAL',
          description: 'Process images on server for deep understanding.',
          infoNote: featureFlags.capabilitiesFetched
              ? 'Server VRAM: ${caps?.vramGb ?? 0}GB'
              : null,
          status: featureFlags.multimodalVision,
          onTap: () => _showMultimodalDialog(
            hapticsHelper,
            featureFlags,
            featureFlagsNotifier,
            caps,
          ),
        ),
        const SizedBox(height: 12),
        // Document Processing toggle
        FeatureToggleTile(
          title: 'Server Document Processing',
          badgeText: 'BETA',
          description: 'Process documents directly on the server.',
          infoNote: featureFlags.capabilitiesFetched
              ? 'Max context: ${featureFlags.maxContextTokens} tokens'
              : null,
          status: featureFlags.documentProcessing,
          onTap: () => _showDocumentProcessingDialog(
            hapticsHelper,
            featureFlags,
            featureFlagsNotifier,
            caps,
          ),
        ),
      ],
    );
  }

  Future<void> _showAttachmentsDialog(
    HapticsHelper hapticsHelper,
    FeatureFlags featureFlags,
    FeatureFlagsNotifier notifier,
    ServerCapabilities? caps,
  ) async {
    hapticsHelper.triggerHaptics();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => FeatureInfoDialog(
        featureName: 'Attachments',
        featureDescription:
            'Enable this to send images and documents in your chat conversations.\n\n'
            'How it works:\n'
            '• Images are processed locally using Edge OCR (Google ML Kit)\n'
            '• Text is extracted on your device, then sent to Parallax\n'
            '• Documents are chunked via Smart Context before sending\n\n'
            'Note: Parallax receives only the extracted text, not raw images.',
        options: [
          FeatureOption(
            title: 'Enable Attachments',
            description:
                'Allow sending images and documents. They will be processed locally using Edge OCR before sending text to Parallax.',
            recommendation:
                'Uses on-device processing - works with any Parallax setup',
            isRecommended: true,
            value: 'enable',
          ),
          FeatureOption(
            title: 'Keep Disabled',
            description:
                'Attachments will remain disabled. You can enable this later.',
            value: 'disable',
          ),
        ],
        currentValue: featureFlags.attachments.isEnabled ? 'enable' : 'disable',
      ),
    );

    if (result != null) {
      await notifier.setAttachmentsEnabled(result == 'enable');
    }
  }

  Future<void> _showMultimodalDialog(
    HapticsHelper hapticsHelper,
    FeatureFlags featureFlags,
    FeatureFlagsNotifier notifier,
    ServerCapabilities? caps,
  ) async {
    hapticsHelper.triggerHaptics();

    // Show info dialog explaining that multimodal is not supported
    await showDialog<void>(
      context: context,
      builder: (context) => FeatureInfoDialog(
        featureName: 'Full Multimodal Vision',
        featureDescription:
            'Server-side image processing is not currently supported by Parallax.\n\n'
            'The Parallax executor only processes text - it cannot analyze raw images directly.\n\n'
            'Instead, use Edge OCR which:\n'
            '• Processes images locally on your device\n'
            '• Extracts text using Google ML Kit\n'
            '• Sends only the extracted text to Parallax\n\n'
            'This works with any Parallax setup and is actually faster!',
        warningMessage:
            'This feature is not available because Parallax does not support server-side image processing.',
        options: [
          FeatureOption(
            title: 'Use Edge OCR (Recommended)',
            description:
                'Process images locally on your device using ML Kit. Works with any Parallax setup.',
            recommendation: 'This is the only supported option',
            isRecommended: true,
            value: 'edge',
          ),
        ],
        currentValue: 'edge',
      ),
    );

    // Always set to edge OCR since multimodal is not supported
    ref.read(settingsControllerProvider.notifier).setVisionPipelineMode('edge');
  }

  Future<void> _showDocumentProcessingDialog(
    HapticsHelper hapticsHelper,
    FeatureFlags featureFlags,
    FeatureFlagsNotifier notifier,
    ServerCapabilities? caps,
  ) async {
    hapticsHelper.triggerHaptics();

    final maxContext = caps?.maxContextWindow ?? 4096;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => FeatureInfoDialog(
        featureName: 'Document Processing',
        featureDescription:
            'Enable document processing to send PDFs and text files in chat.\n\n'
            'How it works:\n'
            '• Documents are processed locally using Smart Context\n'
            '• Large documents are intelligently chunked\n'
            '• Only relevant text is sent to Parallax\n\n'
            'Your server supports up to $maxContext tokens per request.',
        options: [
          FeatureOption(
            title: 'Enable with Smart Context',
            description:
                'Process documents locally with intelligent chunking. Automatically splits large documents to fit context window.',
            recommendation: 'Works with any Parallax setup',
            isRecommended: true,
            value: 'enable',
          ),
          FeatureOption(
            title: 'Keep Disabled',
            description: 'Document processing will remain disabled.',
            value: 'disable',
          ),
        ],
        currentValue: featureFlags.documentProcessing.isEnabled
            ? 'enable'
            : 'disable',
      ),
    );

    if (result != null) {
      if (result == 'enable') {
        await notifier.setDocumentProcessingEnabled(true);
        // Enable Smart Context for document chunking
        ref.read(settingsControllerProvider.notifier).toggleSmartContext(true);
      } else {
        await notifier.setDocumentProcessingEnabled(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final hapticsHelper = ref.read(hapticsHelperProvider);
    const presets = [
      'Concise',
      'Formal',
      'Casual',
      'Detailed',
      'Humorous',
      'Neutral',
      'Custom',
    ];

    ref.listen(settingsControllerProvider, (previous, next) {
      if (previous?.systemPrompt != next.systemPrompt &&
          _systemPromptController.text != next.systemPrompt) {
        _systemPromptController.text = next.systemPrompt;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.secondary),
          onPressed: () {
            hapticsHelper.triggerHaptics();
            context.pop();
          },
        ),
        title: Text(
          'Settings (BETA)',
          style: GoogleFonts.inter(color: AppColors.primary),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'App Settings'),
          const SizedBox(height: 16),
          HapticsSelector(
            currentLevel: state.hapticsLevel,
            onLevelSelected: controller.setHapticsLevel,
            onHapticFeedback: hapticsHelper.triggerHaptics,
          ),
          const SizedBox(height: 32),

          // Streaming Settings Section
          const SectionHeader(title: 'Response Streaming'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.zap, color: AppColors.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Streaming shows responses in real-time as they\'re generated, improving perceived speed.',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StreamingSettingsSection(
            isStreamingEnabled: state.isStreamingEnabled,
            showThinking: state.showThinking,
            onStreamingChanged: controller.setStreamingEnabled,
            onShowThinkingChanged: controller.setShowThinking,
            onHapticFeedback: hapticsHelper.triggerHaptics,
          ),
          const SizedBox(height: 32),

          // Feature Capabilities Section
          _buildFeatureCapabilitiesSection(hapticsHelper),
          const SizedBox(height: 32),

          const SectionHeader(title: 'Response Preference'),
          const SizedBox(height: 16),
          ResponsePreferenceSection(
            systemPromptController: _systemPromptController,
            presets: presets,
            selectedStyle: state.responseStyle,
            onPresetSelected: controller.setResponseStyle,
            onPromptChanged: controller.setSystemPrompt,
            onHapticFeedback: hapticsHelper.triggerHaptics,
          ),
          const SizedBox(height: 32),

          const SectionHeader(title: 'Vision Pipeline'),
          const SizedBox(height: 8),
          Text(
            'Choose how visual content is processed',
            style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          VisionOptionTile(
            title: 'Edge OCR (Recommended)',
            description:
                'Works with any Parallax setup. Processes text locally on your device. Best for standard documents and quick extraction.',
            techNote: 'Uses Google ML Kit',
            value: 'edge',
            groupValue: state.visionPipelineMode,
            onChanged: (val) {
              if (val == null) return;
              hapticsHelper.triggerHaptics();
              controller.setVisionPipelineMode(val);
            },
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final featureFlags = ref.watch(featureFlagsProvider);
              final multimodalAvailable =
                  featureFlags.multimodalVision.isAvailable;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VisionOptionTile(
                    title: 'Full Multimodal (Experimental)',
                    description: multimodalAvailable
                        ? 'Choose this when your Parallax server has vision-capable models and >16GB VRAM. Best for complex visuals that need deep understanding.'
                        : 'Not available: ${featureFlags.multimodalVision.disabledMessage}',
                    value: 'multimodal',
                    groupValue: state.visionPipelineMode,
                    onChanged: multimodalAvailable
                        ? (val) {
                            if (val == null) return;
                            hapticsHelper.triggerHaptics();
                            controller.setVisionPipelineMode(val);
                          }
                        : null,
                  ),
                  if (!multimodalAvailable &&
                      state.visionPipelineMode == 'multimodal')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.alertTriangle,
                              color: AppColors.error,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Multimodal is selected but not available on your server. Consider switching to Edge OCR.',
                                style: GoogleFonts.inter(
                                  color: AppColors.error,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          const SectionHeader(title: 'Document Strategy'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Optimize document processing. Enable Smart Context if your Parallax model doesn\'t support documents natively, has limited VRAM/context window, or for OCR-heavy workflows.',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SmartContextSwitch(
            value: state.isSmartContextEnabled,
            onChanged: (val) {
              hapticsHelper.triggerHaptics();
              controller.toggleSmartContext(val);
            },
          ),
          const SizedBox(height: 24),
          ContextSlider(
            value: state.maxContextTokens,
            onChanged: (val) {
              hapticsHelper.triggerHaptics();
              controller.setMaxContextTokens(val.toInt());
            },
          ),
          const SizedBox(height: 32),

          const SectionHeader(title: 'Data & Storage'),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.1),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => ClearHistoryConfirmationDialog(
                      onClear: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          // Get current session ID to preserve active chat
                          final currentSessionId = ref
                              .read(chatControllerProvider)
                              .currentSessionId;
                          await ref
                              .read(chatArchiveStorageProvider)
                              .clearAllSessionsExcept(currentSessionId);
                          // Trigger history screen refresh
                          ref.read(archiveRefreshProvider.notifier).refresh();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Chat history cleared',
                                style: GoogleFonts.inter(
                                  color: AppColors.primary,
                                ),
                              ),
                              backgroundColor: AppColors.surface,
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to clear history',
                                style: GoogleFonts.inter(
                                  color: AppColors.error,
                                ),
                              ),
                              backgroundColor: AppColors.surface,
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          LucideIcons.trash2,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Clear Chat History',
                              style: GoogleFonts.inter(
                                color: AppColors.error,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Delete all archived chat sessions',
                              style: GoogleFonts.inter(
                                color: AppColors.secondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.chevronRight,
                        color: AppColors.secondary.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          const SectionHeader(title: 'About Parallax Connect'),
          const SizedBox(height: 16),
          const AboutCard(),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'v1.0',
              style: GoogleFonts.inter(
                color: AppColors.secondary.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
