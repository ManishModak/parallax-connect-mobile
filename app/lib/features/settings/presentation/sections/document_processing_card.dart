import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../state/settings_state.dart';
import '../view_models/settings_controller.dart';
import '../widgets/radio_option.dart';

/// Document processing options card
class DocumentProcessingCard extends StatelessWidget {
  final HapticsHelper hapticsHelper;
  final SettingsState state;
  final SettingsController controller;
  final bool serverDocAvailable;

  const DocumentProcessingCard({
    super.key,
    required this.hapticsHelper,
    required this.state,
    required this.controller,
    this.serverDocAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
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
                      LucideIcons.fileText,
                      color: AppColors.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Document Processing Mode',
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
                  'Choose how documents (PDFs, text files) are processed',
                  style: GoogleFonts.inter(
                    color: AppColors.secondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.background),
          // Server mode - recommended default
          RadioOption(
            title: 'Server (Recommended)',
            description: serverDocAvailable
                ? 'Process documents on middleware. Best quality with PyMuPDF.'
                : 'Not available: Server document processing is disabled.',
            techNote: serverDocAvailable
                ? 'Offloads work from device; better PDF parsing'
                : null,
            value: 'server',
            groupValue: state.docProcessingMode,
            isDisabled: !serverDocAvailable,
            onChanged: serverDocAvailable
                ? (val) {
                    hapticsHelper.triggerHaptics();
                    controller.setDocProcessingMode(val!);
                  }
                : null,
          ),
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.background,
          ),
          // Mobile mode - privacy fallback
          RadioOption(
            title: 'Mobile (Privacy)',
            description:
                'Extract text on-device. Use when connecting to untrusted hosts.',
            techNote: 'Document bytes stay local; text sent to LLM',
            value: 'mobile',
            groupValue: state.docProcessingMode,
            onChanged: (val) {
              hapticsHelper.triggerHaptics();
              controller.setDocProcessingMode(val!);
            },
          ),
        ],
      ),
    );
  }
}
