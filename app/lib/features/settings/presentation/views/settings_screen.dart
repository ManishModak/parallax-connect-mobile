import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../../../../core/services/storage/chat_archive_storage.dart';
import '../../../../core/services/server/feature_flags_service.dart';
import '../../../../core/services/utilities/log_upload_service.dart';
import '../../../chat/presentation/view_models/chat_controller.dart';
import '../sections/media_documents_section.dart';
import '../sections/web_search_section.dart';
import '../view_models/settings_controller.dart';
import '../widgets/about_card.dart';
import '../widgets/clear_history_confirmation_dialog.dart';
import '../widgets/device_requirements_card.dart';
import '../widgets/haptics_selector.dart';
import '../widgets/response_preference_section.dart';
import '../widgets/streaming_settings_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _systemPromptController;
  bool _isUploadingLogs = false;

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

          // Media & Documents Section
          MediaDocumentsSection(hapticsHelper: hapticsHelper),
          const SizedBox(height: 32),

          // Web Search Section
          WebSearchSection(hapticsHelper: hapticsHelper),
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
          const SizedBox(height: 12),
          _buildSendLogsTile(),
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

  Widget _buildSendLogsTile() {
    final hapticsHelper = ref.read(hapticsHelperProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isUploadingLogs
              ? null
              : () async {
                  hapticsHelper.triggerHaptics();
                  setState(() => _isUploadingLogs = true);

                  final messenger = ScaffoldMessenger.of(context);
                  final logService = ref.read(logUploadServiceProvider);

                  final (success, message) = await logService.uploadLogs();

                  setState(() => _isUploadingLogs = false);

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        message,
                        style: GoogleFonts.inter(
                          color: success ? AppColors.primary : AppColors.error,
                        ),
                      ),
                      backgroundColor: AppColors.surface,
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
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isUploadingLogs
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : Icon(
                          LucideIcons.upload,
                          color: AppColors.accent,
                          size: 20,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send Logs to Server',
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload debug logs for troubleshooting',
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
