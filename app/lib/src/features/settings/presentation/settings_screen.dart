import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics_helper.dart';
import '../../../core/storage/chat_archive_storage.dart';
import '../../../core/services/device_requirements_service.dart';
import '../../../core/services/feature_flags_service.dart';
import '../../../core/services/server_capabilities_service.dart';
import '../../chat/presentation/chat_controller.dart';
import 'settings_controller.dart';
import 'widgets/about_card.dart';
import 'widgets/clear_history_confirmation_dialog.dart';
import 'widgets/device_requirements_card.dart';
import 'widgets/haptics_selector.dart';
import 'widgets/response_preference_section.dart';
import 'widgets/section_header.dart';
import 'widgets/streaming_settings_section.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(featureFlagsProvider.notifier).refreshCapabilities();
    });
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    super.dispose();
  }

  /// Shows a warning dialog if device doesn't meet requirements
  Future<bool> _checkAndWarnRequirements(
    String featureKey,
    HapticsHelper hapticsHelper,
  ) async {
    final service = ref.read(deviceRequirementsServiceProvider);
    final result = await service.checkRequirements(featureKey);

    if (!result.meetsRequirements) {
      hapticsHelper.triggerHaptics();
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                LucideIcons.alertTriangle,
                color: AppColors.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Device Requirements',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your device may not meet the requirements for this feature:',
                style: GoogleFonts.inter(
                  color: AppColors.secondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ...result.issues.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.x, color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          issue,
                          style: GoogleFonts.inter(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (result.recommendation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  result.recommendation,
                  style: GoogleFonts.inter(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: AppColors.secondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Enable Anyway',
                style: GoogleFonts.inter(color: AppColors.accent),
              ),
            ),
          ],
        ),
      );
      return proceed ?? false;
    }

    // Show warnings if any (but still allow enabling)
    if (result.warnings.isNotEmpty) {
      final deviceInfo = await service.getDeviceInfo();
      if (deviceInfo.isLowEndDevice) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Note: This feature may run slowly on your device',
              style: GoogleFonts.inter(color: AppColors.primary),
            ),
            backgroundColor: AppColors.surface,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    return true;
  }

  Widget _buildWebSearchSection(HapticsHelper hapticsHelper) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Web Search'),
        const SizedBox(height: 20),
        _buildExpandableFeatureTile(
          icon: LucideIcons.globe,
          title: 'Web Search',
          badgeText: 'NEW',
          description: 'Allow the AI to search the web for real-time info',
          isEnabled: state.isWebSearchEnabled,
          onToggle: (val) async {
            hapticsHelper.triggerHaptics();
            await controller.setWebSearchEnabled(val);
          },
          details: [
            'Fetches real-time information from the web',
            'Results are injected into the context window',
            'DuckDuckGo is free and unlimited (Default)',
            'Brave Search requires a free API key but is more robust',
          ],
        ),
        if (state.isWebSearchEnabled) ...[
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                _buildRadioOption(
                  title: 'DuckDuckGo (Recommended)',
                  description: 'Free, unlimited, privacy-focused scraping.',
                  value: 'duckduckgo',
                  groupValue: state.webSearchProvider,
                  onChanged: (val) {
                    hapticsHelper.triggerHaptics();
                    controller.setWebSearchProvider(val!);
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildRadioOption(
                  title: 'Brave Search API',
                  description: 'Official API. High quality, requires key.',
                  techNote: 'Free tier: 2,000 queries/month',
                  value: 'brave',
                  groupValue: state.webSearchProvider,
                  onChanged: (val) {
                    hapticsHelper.triggerHaptics();
                    controller.setWebSearchProvider(val!);
                  },
                ),
                if (state.webSearchProvider == 'brave') ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Brave Search API Key',
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller:
                              TextEditingController(
                                  text: state.braveSearchApiKey,
                                )
                                ..selection = TextSelection.fromPosition(
                                  TextPosition(
                                    offset:
                                        state.braveSearchApiKey?.length ?? 0,
                                  ),
                                ),
                          onChanged: (val) {
                            controller.setBraveSearchApiKey(val);
                          },
                          style: GoogleFonts.inter(color: AppColors.primary),
                          decoration: InputDecoration(
                            hintText: 'Enter your API key',
                            hintStyle: GoogleFonts.inter(
                              color: AppColors.secondary.withValues(alpha: 0.5),
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Get a free key at api.search.brave.com',
                          style: GoogleFonts.inter(
                            color: AppColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Deep Search',
                                  style: GoogleFonts.inter(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'INTENSIVE',
                                    style: GoogleFonts.inter(
                                      color: AppColors.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Analyzes more results and reads full page content. Slower but more comprehensive.',
                              style: GoogleFonts.inter(
                                color: AppColors.secondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: state.isDeepSearchEnabled,
                        onChanged: (val) {
                          hapticsHelper.triggerHaptics();
                          controller.setDeepSearchEnabled(val);
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.3,
                        ),
                        inactiveThumbColor: AppColors.secondary,
                        inactiveTrackColor: AppColors.background,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Builds the unified Media & Documents section
  Widget _buildMediaAndDocumentsSection(HapticsHelper hapticsHelper) {
    final featureFlags = ref.watch(featureFlagsProvider);
    final capsAsync = ref.watch(serverCapabilitiesProvider);
    final featureFlagsNotifier = ref.read(featureFlagsProvider.notifier);
    final caps = capsAsync.value;
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Media & Documents')),
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
        const SizedBox(height: 20),
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
                      ? 'Configure how images and documents are processed. Server VRAM: ${caps?.vramGb ?? 0}GB, Max context: ${featureFlags.maxContextTokens} tokens'
                      : 'Connect to your Parallax server to detect available features and configure processing options.',
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

        // Attachments Master Toggle
        _buildExpandableFeatureTile(
          icon: LucideIcons.paperclip,
          title: 'Attachments',
          badgeText: 'BETA',
          description: 'Send images and documents in chat conversations',
          requirementKey: 'attachments',
          isEnabled: featureFlags.attachments.isEnabled,
          onToggle: (val) async {
            hapticsHelper.triggerHaptics();
            if (val) {
              final canEnable = await _checkAndWarnRequirements(
                'attachments',
                hapticsHelper,
              );
              if (!canEnable) return;
            }
            await featureFlagsNotifier.setAttachmentsEnabled(val);
          },
          details: [
            'Images are processed locally using Edge OCR (Google ML Kit)',
            'Text is extracted on your device, then sent to Parallax',
            'Documents are chunked via Smart Context before sending',
            'Parallax receives only the extracted text, not raw images',
            'Minimum requirement: 2GB RAM',
          ],
        ),
        const SizedBox(height: 12),

        // Vision Processing Options (only show when attachments enabled)
        if (featureFlags.attachments.isEnabled) ...[
          _buildVisionProcessingCard(
            hapticsHelper,
            featureFlags,
            state,
            controller,
            caps,
          ),
          const SizedBox(height: 12),
        ],

        // Document Processing
        _buildExpandableFeatureTile(
          icon: LucideIcons.fileText,
          title: 'Document Processing',
          badgeText: 'BETA',
          description: 'Process PDFs and text files with intelligent chunking',
          requirementKey: 'document_processing',
          isEnabled: featureFlags.documentProcessing.isEnabled,
          onToggle: (val) async {
            hapticsHelper.triggerHaptics();
            if (val) {
              final canEnable = await _checkAndWarnRequirements(
                'document_processing',
                hapticsHelper,
              );
              if (!canEnable) return;
            }
            await featureFlagsNotifier.setDocumentProcessingEnabled(val);
            if (val) {
              controller.toggleSmartContext(true);
            }
          },
          details: [
            'Documents are processed locally using Smart Context',
            'Large documents are intelligently chunked to fit context window',
            'Only relevant text portions are sent to Parallax',
            'Server supports up to ${caps?.maxContextWindow ?? 4096} tokens per request',
            'Minimum requirement: 3GB RAM (4GB+ for large PDFs)',
          ],
        ),

        // Document Strategy Options (only show when document processing enabled)
        if (featureFlags.documentProcessing.isEnabled) ...[
          const SizedBox(height: 12),
          _buildDocumentStrategyCard(hapticsHelper, state, controller),
        ],
      ],
    );
  }

  /// Builds the vision processing options card
  Widget _buildVisionProcessingCard(
    HapticsHelper hapticsHelper,
    FeatureFlags featureFlags,
    dynamic state,
    dynamic controller,
    ServerCapabilities? caps,
  ) {
    final multimodalAvailable = featureFlags.multimodalVision.isAvailable;

    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.eye, color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Vision Processing Mode',
                      style: GoogleFonts.inter(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how visual content (images) is processed',
                  style: GoogleFonts.inter(
                    color: AppColors.secondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.background),
          // Edge OCR Option
          _buildRadioOption(
            title: 'Edge OCR (Recommended)',
            description:
                'Process images locally on your device using Google ML Kit. Works with any Parallax setup.',
            techNote: 'Best for standard documents and quick text extraction',
            value: 'edge',
            groupValue: state.visionPipelineMode,
            onChanged: (val) {
              hapticsHelper.triggerHaptics();
              controller.setVisionPipelineMode(val!);
            },
          ),
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.background,
          ),
          // Multimodal Option
          _buildRadioOption(
            title: 'Full Multimodal (Experimental)',
            description: multimodalAvailable
                ? 'Server-side processing for complex visuals. Requires vision-capable models and >16GB VRAM.'
                : 'Not available: ${featureFlags.multimodalVision.disabledMessage}',
            techNote: multimodalAvailable
                ? 'Best for complex visuals needing deep understanding'
                : null,
            value: 'multimodal',
            groupValue: state.visionPipelineMode,
            isDisabled: !multimodalAvailable,
            onChanged: multimodalAvailable
                ? (val) {
                    hapticsHelper.triggerHaptics();
                    controller.setVisionPipelineMode(val!);
                  }
                : null,
          ),
          // Warning if multimodal selected but not available
          if (!multimodalAvailable && state.visionPipelineMode == 'multimodal')
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
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
                      'Multimodal is selected but not available. Consider switching to Edge OCR.',
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
        ],
      ),
    );
  }

  /// Builds the document strategy options card
  Widget _buildDocumentStrategyCard(
    HapticsHelper hapticsHelper,
    dynamic state,
    dynamic controller,
  ) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.settings2,
                      color: AppColors.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Document Strategy',
                      style: GoogleFonts.inter(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Optimize how documents are processed and sent to Parallax',
                  style: GoogleFonts.inter(
                    color: AppColors.secondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.background),
          // Smart Context Toggle
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Context Window',
                            style: GoogleFonts.inter(
                              color: AppColors.primaryMildVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Automatically uses RAG mode for large documents. Enable if your Parallax model doesn\'t support documents natively, has limited VRAM/context window, or for OCR-heavy workflows.',
                            style: GoogleFonts.inter(
                              color: AppColors.secondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: state.isSmartContextEnabled,
                      onChanged: (val) {
                        hapticsHelper.triggerHaptics();
                        controller.toggleSmartContext(val);
                      },
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(
                        alpha: 0.3,
                      ),
                      inactiveThumbColor: AppColors.secondary,
                      inactiveTrackColor: AppColors.background,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.background),
          // Context Slider
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Max Context Injection',
                      style: GoogleFonts.inter(
                        color: AppColors.primaryMildVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${state.maxContextTokens} tokens',
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Maximum document context sent to server. Higher values use more tokens and VRAM.',
                  style: GoogleFonts.inter(
                    color: AppColors.secondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.background,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.1),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                  ),
                  child: Slider(
                    value: state.maxContextTokens.toDouble(),
                    min: 2000,
                    max: 16000,
                    divisions: 14,
                    label: '${state.maxContextTokens}',
                    onChanged: (val) {
                      hapticsHelper.triggerHaptics();
                      controller.setMaxContextTokens(val.toInt());
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '2k',
                        style: GoogleFonts.inter(
                          color: AppColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '16k',
                        style: GoogleFonts.inter(
                          color: AppColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds an expandable feature tile with toggle and details
  Widget _buildExpandableFeatureTile({
    required IconData icon,
    required String title,
    String? badgeText,
    required String description,
    String? requirementKey,
    required bool isEnabled,
    required Future<void> Function(bool) onToggle,
    required List<String> details,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.secondary.withValues(alpha: 0.1),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isEnabled ? AppColors.primary : AppColors.secondary,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              description,
              style: GoogleFonts.inter(
                color: AppColors.secondary,
                fontSize: 13,
              ),
            ),
          ),
          trailing: Switch(
            value: isEnabled,
            onChanged: onToggle,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary;
              }
              return AppColors.secondary;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary.withValues(alpha: 0.5);
              }
              return AppColors.secondary.withValues(alpha: 0.2);
            }),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it works:',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...details.map(
                    (detail) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: GoogleFonts.inter(
                              color: AppColors.accent,
                              fontSize: 13,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              detail,
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a radio option for selection lists
  Widget _buildRadioOption({
    required String title,
    required String description,
    String? techNote,
    required String value,
    required String groupValue,
    bool isDisabled = false,
    required ValueChanged<String?>? onChanged,
  }) {
    final isSelected = value == groupValue;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: isDisabled ? null : () => onChanged?.call(value),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.secondary,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.primaryMildVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        color: AppColors.secondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    if (techNote != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          techNote,
                          style: GoogleFonts.inter(
                            color: AppColors.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          // Haptics Settings Section
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'HAPTICS SETTINGS',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: ' - Button taps + typing feel during streaming',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          HapticsSelector(
            currentLevel: state.hapticsLevel,
            onLevelSelected: controller.setHapticsLevel,
            onHapticFeedback: hapticsHelper.triggerHaptics,
          ),
          const SizedBox(height: 32),

          // Streaming Settings Section
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'RESPONSE STREAMING',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' - Streaming shows responses in real-time as they\'re generated, improving perceived speed.',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
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

          // Media & Documents Section (merged from Feature Capabilities, Vision Pipeline, Document Strategy)
          _buildMediaAndDocumentsSection(hapticsHelper),
          const SizedBox(height: 32),

          // Web Search Section
          _buildWebSearchSection(hapticsHelper),
          const SizedBox(height: 32),

          // Response Preference Section
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'RESPONSE PREFERENCE',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' - Customize how the AI behaves and responds to you.',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

          // Device Compatibility Section
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'DEVICE COMPATIBILITY',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' - Check if your device meets the requirements for advanced features.',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const DeviceRequirementsCard(),
          const SizedBox(height: 32),

          // Data & Storage Section
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'DATA & STORAGE',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: ' - Manage your chat history and stored data.',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildClearHistoryTile(),
          const SizedBox(height: 32),

          // About Section
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'ABOUT PARALLAX CONNECT',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: ' - Learn more about the app and its philosophy.',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  Widget _buildClearHistoryTile() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
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
                    final currentSessionId = ref
                        .read(chatControllerProvider)
                        .currentSessionId;
                    await ref
                        .read(chatArchiveStorageProvider)
                        .clearAllSessionsExcept(currentSessionId);
                    ref.read(archiveRefreshProvider.notifier).refresh();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Chat history cleared',
                          style: GoogleFonts.inter(color: AppColors.primary),
                        ),
                        backgroundColor: AppColors.surface,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to clear history',
                          style: GoogleFonts.inter(color: AppColors.error),
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
    );
  }
}
