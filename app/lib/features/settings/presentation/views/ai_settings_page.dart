import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../view_models/settings_controller.dart';
import '../widgets/response_preference_section.dart';

/// AI Settings page containing response preferences and system prompts
class AISettingsPage extends ConsumerStatefulWidget {
  const AISettingsPage({super.key});

  @override
  ConsumerState<AISettingsPage> createState() => _AISettingsPageState();
}

class _AISettingsPageState extends ConsumerState<AISettingsPage> {
  late TextEditingController _systemPromptController;

  static const _presets = [
    'Concise',
    'Formal',
    'Casual',
    'Detailed',
    'Humorous',
    'Neutral',
    'Custom',
  ];

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
          'AI Settings',
          style: GoogleFonts.inter(color: AppColors.primary),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                    text: ' - Customize how the AI behaves and responds to you',
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
            presets: _presets,
            selectedStyle: state.responseStyle,
            onPresetSelected: controller.setResponseStyle,
            onPromptChanged: controller.setSystemPrompt,
            onHapticFeedback: hapticsHelper.triggerHaptics,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
