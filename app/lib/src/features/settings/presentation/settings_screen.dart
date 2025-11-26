import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics_helper.dart';
import '../../../core/storage/chat_archive_storage.dart';
import '../../chat/presentation/chat_controller.dart';
import 'settings_controller.dart';
import 'widgets/about_card.dart';
import 'widgets/clear_history_confirmation_dialog.dart';
import 'widgets/context_slider.dart';
import 'widgets/haptics_selector.dart';
import 'widgets/response_preference_section.dart';
import 'widgets/section_header.dart';
import 'widgets/smart_context_switch.dart';
import 'widgets/vision_option_tile.dart';

// TODO: Implement dynamic feature disabling based on requirements:
// - Client device specs (minimum device capabilities for certain features)
// - Parallax server capabilities:
//   * VRAM availability (disable Full Multimodal if <16GB)
//   * Vision model support (disable Full Multimodal if vision not supported)
//   * Document processing support (auto-enable Smart Context if not supported)
//   * Model context window size (adjust max context slider range)
// Features should query server /info endpoint and device capabilities to
// show/hide or disable options that won't work with current configuration.

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
          const SectionHeader(title: 'App Settings'),
          const SizedBox(height: 16),
          HapticsSelector(
            currentLevel: state.hapticsLevel,
            onLevelSelected: controller.setHapticsLevel,
            onHapticFeedback: hapticsHelper.triggerHaptics,
          ),
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
          VisionOptionTile(
            title: 'Full Multimodal (Experimental)',
            description:
                'Choose this when your Parallax server has vision-capable models and >16GB VRAM. Best for complex visuals that need deep understanding.',
            value: 'multimodal',
            groupValue: state.visionPipelineMode,
            onChanged: (val) {
              if (val == null) return;
              hapticsHelper.triggerHaptics();
              controller.setVisionPipelineMode(val);
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
                          ref
                              .read(archiveRefreshProvider.notifier)
                              .refresh();
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
