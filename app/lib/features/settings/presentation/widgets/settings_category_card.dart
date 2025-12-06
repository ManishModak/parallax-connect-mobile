import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';

/// A premium card widget for displaying a settings category in a grid layout.
/// Features a subtle glass-like effect and careful typography.
class SettingsCategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final Color? iconColor;

  const SettingsCategoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    // Default to brand color if no color provided, or accent if brand not suitable
    final effectiveColor = iconColor ?? AppColors.brand;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        overlayColor: MaterialStateProperty.all(
          effectiveColor.withValues(alpha: 0.1),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Subtle background gradient splash
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        effectiveColor.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon & Badge Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: effectiveColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: effectiveColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(icon, color: effectiveColor, size: 24),
                        ),
                        const Spacer(),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: effectiveColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: effectiveColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              badge!,
                              style: GoogleFonts.outfit(
                                color: effectiveColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const Spacer(),

                    // Text Content
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: AppColors.secondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Arrow indicator
              Positioned(
                right: 16,
                bottom: 16,
                child: Icon(
                  LucideIcons.arrowRight,
                  color: AppColors.secondary.withValues(alpha: 0.2),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
