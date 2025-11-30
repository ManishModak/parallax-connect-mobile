import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';

class SetupInstructionsCard extends StatelessWidget {
  final bool isLocal;
  final VoidCallback onOpenGuide;
  final VoidCallback onCopyLink;

  const SetupInstructionsCard({
    super.key,
    required this.isLocal,
    required this.onOpenGuide,
    required this.onCopyLink,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isLocal
        ? AppColors.modeLocal.withValues(alpha: 0.3)
        : AppColors.modeCloud.withValues(alpha: 0.3);
    final iconColor =
        isLocal ? AppColors.modeLocal : AppColors.modeCloud;
    final lightColor =
        isLocal ? AppColors.modeLocalLight : AppColors.modeCloudLight;
    final lighterColor = isLocal
        ? AppColors.modeLocalLighter
        : AppColors.modeCloudLighter;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLocal ? LucideIcons.info : LucideIcons.cloud,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isLocal ? 'Local Mode Setup' : 'Cloud Mode Setup',
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'To connect, set up the server on your computer first.',
            style: GoogleFonts.inter(
              color: AppColors.secondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenGuide,
                  icon: const Icon(LucideIcons.externalLink, size: 16),
                  label: Text(
                    'View Server Setup Guide',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Copy guide link',
                child: OutlinedButton(
                  onPressed: onCopyLink,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Icon(LucideIcons.copy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'After the server starts, copy the URL shown in the terminal '
            'or scan the QR code from that terminal to paste it here.',
            style: GoogleFonts.inter(
              color: AppColors.secondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isLocal
                      ? AppColors.modeLocal
                      : AppColors.modeCloud)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isLocal ? LucideIcons.wifi : LucideIcons.globe,
                      size: 16,
                      color: lightColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLocal ? 'Local Mode' : 'Cloud Mode',
                      style: GoogleFonts.inter(
                        color: lightColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isLocal
                      ? 'Both devices must be on the same Wi-Fi.'
                      : 'Internet connection required on both devices.',
                  style: GoogleFonts.inter(
                    color: lighterColor,
                    fontSize: 11,
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

