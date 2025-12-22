import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../../core/utils/haptics_helper.dart';

class SourcesPill extends ConsumerWidget {
  final int sourceCount;
  final VoidCallback onTap;

  const SourcesPill({
    super.key,
    required this.sourceCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'View $sourceCount sources',
      child: InkWell(
        onTap: () {
          ref.read(hapticsHelperProvider).triggerHaptics();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Overlapping Icons (Simulated with a generic globe for now, or multiple if we had favicons)
            SizedBox(
              width: 24,
              height: 24,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.background,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.globe,
                        size: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  if (sourceCount > 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '+${sourceCount - 1}',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$sourceCount Sources',
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    ));
  }
}
