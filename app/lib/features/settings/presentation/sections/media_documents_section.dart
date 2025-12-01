import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../core/services/server/feature_flags_service.dart';
import '../../../../core/services/server/server_capabilities_service.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../helpers/requirements_checker.dart';
import '../view_models/settings_controller.dart';
import '../widgets/expandable_feature_tile.dart';
import '../widgets/section_header.dart';
import 'document_strategy_card.dart';
import 'vision_processing_card.dart';

/// Media & Documents settings section
class MediaDocumentsSection extends ConsumerWidget {
  final HapticsHelper hapticsHelper;

  const MediaDocumentsSection({super.key, required this.hapticsHelper});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        ExpandableFeatureTile(
          icon: LucideIcons.paperclip,
          title: 'Attachments',
          badgeText: 'BETA',
          description: 'Send images and documents in chat conversations',
          isEnabled: featureFlags.attachments.isEnabled,
          onToggle: (val) async {
            hapticsHelper.triggerHaptics();
            if (val) {
              final canEnable =
                  await RequirementsChecker.checkAndWarnRequirements(
                    context,
                    ref,
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
        if (featureFlags.attachments.isEnabled) ...[
          VisionProcessingCard(
            hapticsHelper: hapticsHelper,
            featureFlags: featureFlags,
            state: state,
            controller: controller,
            caps: caps,
          ),
          const SizedBox(height: 12),
        ],
        ExpandableFeatureTile(
          icon: LucideIcons.fileText,
          title: 'Document Processing',
          badgeText: 'BETA',
          description: 'Process PDFs and text files with intelligent chunking',
          isEnabled: featureFlags.documentProcessing.isEnabled,
          onToggle: (val) async {
            hapticsHelper.triggerHaptics();
            if (val) {
              final canEnable =
                  await RequirementsChecker.checkAndWarnRequirements(
                    context,
                    ref,
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
        if (featureFlags.documentProcessing.isEnabled) ...[
          const SizedBox(height: 12),
          DocumentStrategyCard(
            hapticsHelper: hapticsHelper,
            state: state,
            controller: controller,
          ),
        ],
      ],
    );
  }
}
