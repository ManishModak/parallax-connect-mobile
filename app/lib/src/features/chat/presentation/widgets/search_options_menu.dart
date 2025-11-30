import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../settings/presentation/settings_controller.dart';

class SearchOptionsMenu extends ConsumerWidget {
  final VoidCallback onWebSearchToggle;
  final VoidCallback onDeepSearchToggle;

  const SearchOptionsMenu({
    super.key,
    required this.onWebSearchToggle,
    required this.onDeepSearchToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final isWebSearchEnabled = settingsState.isWebSearchEnabled;
    final isDeepSearchEnabled = settingsState.isDeepSearchEnabled;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Search Options',
              style: GoogleFonts.inter(
                color: AppColors.primaryMildVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildOptionTile(
            context,
            icon: LucideIcons.globe,
            title: 'Web Search',
            subtitle: 'Access real-time information',
            isActive: isWebSearchEnabled,
            onTap: onWebSearchToggle,
          ),
          if (isWebSearchEnabled) ...[
            const Divider(height: 12, color: AppColors.surfaceLight),
            _buildOptionTile(
              context,
              icon: isDeepSearchEnabled
                  ? LucideIcons.layers
                  : LucideIcons.search,
              title: 'Deep Search',
              subtitle: 'More results, full page reading',
              isActive: isDeepSearchEnabled,
              activeColor: AppColors.accent,
              onTap: onDeepSearchToggle,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final color = activeColor ?? AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withValues(alpha: 0.1)
                      : AppColors.surfaceLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isActive ? color : AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: isActive ? color : AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: AppColors.secondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive) Icon(LucideIcons.check, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
