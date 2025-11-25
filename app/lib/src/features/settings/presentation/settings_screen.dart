import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics_helper.dart';
import '../../chat/presentation/archived_sessions_screen.dart';
import 'settings_controller.dart';

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
            ref.read(hapticsHelperProvider).triggerHaptics();
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
          // Section 1: App Settings
          _buildSectionHeader('App Settings'),
          const SizedBox(height: 16),
          _buildHapticsSelector(context, state.hapticsLevel, controller, ref),
          const SizedBox(height: 32),

          // Section 2: Response Preference
          _buildSectionHeader('Response Preference'),
          const SizedBox(height: 16),
          _buildResponsePreferenceSection(context, state, controller, ref),
          const SizedBox(height: 32),

          // Section 3: Vision Pipeline
          _buildSectionHeader('Vision Pipeline'),
          const SizedBox(height: 8),
          Text(
            'Choose how images/documents are processed',
            style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildVisionOption(
            title: 'Edge OCR (Recommended)',
            description:
                'Extracts text on-phone. Fastest. Works with all models. Best for standard documents and quick text extraction.',
            techNote: 'Uses Google ML Kit',
            value: 'edge',
            groupValue: state.visionPipelineMode,
            onChanged: (val) {
              ref.read(hapticsHelperProvider).triggerHaptics();
              controller.setVisionPipelineMode(val!);
            },
          ),
          const SizedBox(height: 12),
          _buildVisionOption(
            title: 'Full Multimodal (Experimental)',
            description:
                'Sends raw image to server. Requires Llama 3.2 Vision. Best for complex diagrams, handwriting, or when OCR fails. Note: Requires server with >16GB VRAM.',
            value: 'multimodal',
            groupValue: state.visionPipelineMode,
            onChanged: (val) {
              ref.read(hapticsHelperProvider).triggerHaptics();
              controller.setVisionPipelineMode(val!);
            },
          ),
          const SizedBox(height: 32),

          // Section 4: Document Strategy
          _buildSectionHeader('Document Strategy'),
          const SizedBox(height: 16),
          _buildSmartContextSwitch(state.isSmartContextEnabled, (val) {
            ref.read(hapticsHelperProvider).triggerHaptics();
            controller.toggleSmartContext(val);
          }),
          const SizedBox(height: 24),
          _buildContextSlider(state.maxContextTokens, (val) {
            ref.read(hapticsHelperProvider).triggerHaptics();
            controller.setMaxContextTokens(val.toInt());
          }),
          const SizedBox(height: 32),

          // Section 5: About
          _buildSectionHeader('About Parallax Connect'),
          const SizedBox(height: 16),
          _buildAboutCard(),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'v1.0',
              style: GoogleFonts.inter(
                color: AppColors.secondary.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: AppColors.secondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildHapticsSelector(
    BuildContext context,
    String currentLevel,
    SettingsController controller,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.secondary.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              _buildHapticOption(
                context,
                'None',
                'none',
                currentLevel,
                LucideIcons.smartphone,
                controller,
                ref,
              ),
              Container(width: 1, color: AppColors.secondary.withOpacity(0.1)),
              _buildHapticOption(
                context,
                'Min',
                'min',
                currentLevel,
                LucideIcons.vibrate,
                controller,
                ref,
              ),
              Container(width: 1, color: AppColors.secondary.withOpacity(0.1)),
              _buildHapticOption(
                context,
                'Max',
                'max',
                currentLevel,
                LucideIcons.waves,
                controller,
                ref,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHapticOption(
    BuildContext context,
    String label,
    String value,
    String groupValue,
    IconData icon,
    SettingsController controller,
    WidgetRef ref,
  ) {
    final isSelected = value == groupValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(hapticsHelperProvider).triggerHaptics();
          controller.setHapticsLevel(value);
        },
        child: Container(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.primary : AppColors.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isSelected ? AppColors.primary : AppColors.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearDataTile(
    BuildContext context,
    SettingsController controller,
    WidgetRef ref,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(LucideIcons.trash2, color: AppColors.error),
        ),
        title: Text(
          'Clear Data',
          style: GoogleFonts.inter(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          'Delete all chat history and reset settings',
          style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 12),
        ),
        onTap: () {
          ref.read(hapticsHelperProvider).triggerHaptics();
          _showClearDataDialog(context, controller, ref);
        },
      ),
    );
  }

  Future<void> _showClearDataDialog(
    BuildContext context,
    SettingsController controller,
    WidgetRef ref,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Clear All Data?',
          style: GoogleFonts.inter(color: AppColors.primary),
        ),
        content: Text(
          'This action cannot be undone. All your chat history and settings will be permanently deleted.',
          style: GoogleFonts.inter(color: AppColors.secondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(hapticsHelperProvider).triggerHaptics();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.secondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(hapticsHelperProvider).triggerHaptics();
              controller.clearAllData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'All data cleared',
                    style: GoogleFonts.inter(color: AppColors.background),
                  ),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: Text(
              'Clear',
              style: GoogleFonts.inter(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisionOption({
    required String title,
    required String description,
    String? techNote,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withOpacity(0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.secondary.withOpacity(0.1),
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: isSelected
                ? AppColors.primary
                : AppColors.primaryMildVariant,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.inter(
                color: AppColors.secondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (techNote != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.secondary.withOpacity(0.2),
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
    );
  }

  Widget _buildSmartContextSwitch(bool value, ValueChanged<bool> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.1)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        activeTrackColor: AppColors.primary.withOpacity(0.3),
        inactiveThumbColor: AppColors.secondary,
        inactiveTrackColor: AppColors.background,
        title: Text(
          'Smart Context Window',
          style: GoogleFonts.inter(
            color: AppColors.primaryMildVariant,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Automatically switches to RAG mode for large files to prevent server OOM (Out of Memory). Recommended for RTX 4060 and similar GPUs.',
            style: GoogleFonts.inter(
              color: AppColors.secondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextSlider(int value, ValueChanged<double> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.1)),
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$value tokens',
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
            'How much PDF text to send to the server at once. Lower values = less VRAM usage. Higher values = better context but may cause OOM.',
            style: GoogleFonts.inter(
              color: AppColors.secondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.background,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 2000,
              max: 16000,
              divisions: 14, // (16000 - 2000) / 1000 = 14 steps
              label: '$value',
              onChanged: onChanged,
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
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parallax Connect is designed to run on Commodity Edge Hardware. We optimized the app so that any standard smartphone from the last 4 years can act as an intelligent input node. We utilize the Neural Engine (NPU) found in modern mobile chipsets to handle the vision pipeline, ensuring the heavy GPU on the server is reserved strictly for reasoning.',
            style: GoogleFonts.inter(
              color: AppColors.secondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildRequirementRow('Client Requirements:', [
            'Android 10+ / iOS 14+ (Recommended)',
            '4GB RAM minimum, 6GB+ recommended',
            '12MP camera with autofocus for OCR',
          ]),
          const SizedBox(height: 12),
          _buildRequirementRow('Server Requirements:', [
            'Parallax-compatible node (Tested on RTX 4060)',
          ]),
        ],
      ),
    );
  }

  Widget _buildResponsePreferenceSection(
    BuildContext context,
    SettingsState state,
    SettingsController controller,
    WidgetRef ref,
  ) {
    final presets = [
      'Concise',
      'Formal',
      'Casual',
      'Detailed',
      'Humorous',
      'Neutral',
      'Custom',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.secondary.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _systemPromptController,
                maxLines: 4,
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 14,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter system instructions...',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.secondary.withOpacity(0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  controller.setSystemPrompt(value);
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((preset) {
                  final isSelected = state.responseStyle == preset;
                  return ChoiceChip(
                    label: Text(
                      preset,
                      style: GoogleFonts.inter(
                        color: isSelected
                            ? AppColors.background
                            : AppColors.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(hapticsHelperProvider).triggerHaptics();
                        controller.setResponseStyle(preset);
                      }
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.secondary.withOpacity(0.2),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementRow(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: AppColors.primaryMildVariant,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
