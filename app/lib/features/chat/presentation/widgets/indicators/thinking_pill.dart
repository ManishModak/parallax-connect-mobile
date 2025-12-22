import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../../core/utils/haptics_helper.dart';

class ThinkingPill extends ConsumerWidget {
  final VoidCallback onTap;

  const ThinkingPill({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'View thought process',
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
            SizedBox(
              height: 24,
              width: 24,
              child: const Icon(
                LucideIcons.brainCircuit,
                size: 16,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Thought Process',
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
