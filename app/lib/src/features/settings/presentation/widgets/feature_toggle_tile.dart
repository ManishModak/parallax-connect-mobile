import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/feature_flags_service.dart';

/// A toggle tile for features that can be enabled/disabled
/// Shows availability status and info about why feature might be unavailable
class FeatureToggleTile extends StatelessWidget {
  final String title;
  final String description;
  final String? infoNote;
  final String? badgeText;
  final FeatureStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onInfoTap;

  const FeatureToggleTile({
    super.key,
    required this.title,
    required this.description,
    this.infoNote,
    this.badgeText,
    required this.status,
    this.onTap,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = status.isEnabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEnabled
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.secondary.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                                    color: AppColors.accent.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badgeText!,
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
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: GoogleFonts.inter(
                              color: AppColors.secondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          if (infoNote != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              infoNote!,
                              style: GoogleFonts.inter(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status indicator instead of switch
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? AppColors.successDark.withValues(alpha: 0.15)
                            : AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isEnabled ? LucideIcons.check : LucideIcons.x,
                            size: 14,
                            color: isEnabled
                                ? AppColors.successDark
                                : AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isEnabled ? 'On' : 'Off',
                            style: GoogleFonts.inter(
                              color: isEnabled
                                  ? AppColors.successDark
                                  : AppColors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Tap to configure hint
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.03),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.settings2,
                      color: AppColors.secondary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tap to configure',
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
      ),
    );
  }
}
