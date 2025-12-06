import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../../../../core/services/storage/chat_archive_storage.dart';
import '../../../../core/services/utilities/log_upload_service.dart';
import '../../../chat/presentation/view_models/chat_controller.dart';
import '../view_models/settings_controller.dart';
import '../widgets/haptics_selector.dart';
import '../widgets/streaming_settings_section.dart';
import '../widgets/clear_history_confirmation_dialog.dart';

/// App Settings page containing haptics, streaming, and data management
class AppSettingsPage extends ConsumerStatefulWidget {
  const AppSettingsPage({super.key});

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends ConsumerState<AppSettingsPage> {
  bool _isUploadingLogs = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final hapticsHelper = ref.read(hapticsHelperProvider);

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
          'App Settings',
          style: GoogleFonts.inter(color: AppColors.primary),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Haptics Settings Section
          _buildSectionHeader(
            'HAPTICS SETTINGS',
            'Button taps + typing feel during streaming',
          ),
          const SizedBox(height: 16),
          HapticsSelector(
            currentLevel: state.hapticsLevel,
            onLevelSelected: controller.setHapticsLevel,
            onHapticFeedback: hapticsHelper.triggerHaptics,
          ),
          const SizedBox(height: 32),

          // Streaming Settings Section
          _buildSectionHeader(
            'RESPONSE STREAMING',
            'Real-time response display for improved perceived speed',
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

          // Data & Storage Section
          _buildSectionHeader(
            'DATA & STORAGE',
            'Manage your chat history and stored data',
          ),
          const SizedBox(height: 16),
          _buildClearHistoryTile(hapticsHelper),
          const SizedBox(height: 12),
          _buildSendLogsTile(hapticsHelper),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: GoogleFonts.inter(
                color: AppColors.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
            TextSpan(
              text: ' - $subtitle',
              style: GoogleFonts.inter(
                color: AppColors.secondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearHistoryTile(HapticsHelper hapticsHelper) {
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
            hapticsHelper.triggerHaptics();
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

  Widget _buildSendLogsTile(HapticsHelper hapticsHelper) {
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
