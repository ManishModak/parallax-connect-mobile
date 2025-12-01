import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../settings/presentation/view_models/settings_controller.dart';

class SearchOptionsMenu extends ConsumerWidget {
  final VoidCallback onDeepSearchToggle;
  final VoidCallback onDeeperSearchToggle;

  const SearchOptionsMenu({
    super.key,
    required this.onDeepSearchToggle,
    required this.onDeeperSearchToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final depth = settingsState.webSearchDepth;
    final isDeep = depth == 'deep';
    final isDeeper = depth == 'deeper';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.chatInputBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.background.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuItem(
              icon: LucideIcons.globe,
              label: 'Deep Search',
              isActive: isDeep,
              onTap: onDeepSearchToggle,
            ),
            const SizedBox(height: 4),
            _buildMenuItem(
              icon: LucideIcons.layers,
              label: 'Deeper Search',
              isActive: isDeeper,
              onTap: onDeeperSearchToggle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isActive ? AppColors.primary : AppColors.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: isActive ? AppColors.primary : AppColors.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isActive)
              Icon(LucideIcons.check, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
