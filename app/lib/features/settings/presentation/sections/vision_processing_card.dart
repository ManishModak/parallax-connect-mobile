import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../core/services/server/feature_flags_service.dart';
import '../../../../core/services/server/server_capabilities_service.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../state/settings_state.dart';
import '../view_models/settings_controller.dart';
import '../widgets/radio_option.dart';

/// Vision processing options card
class VisionProcessingCard extends StatelessWidget {
  final HapticsHelper hapticsHelper;
  final FeatureFlags featureFlags;
  final SettingsState state;
  final SettingsController controller;
  final ServerCapabilities? caps;

  const VisionProcessingCard({
    super.key,
    required this.hapticsHelper,
    required this.featureFlags,
    required this.state,
    required this.controller,
    this.caps,
  });

  @override
  Widget build(BuildContext context) {
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
          RadioOption(
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
          RadioOption(
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
}
