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
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.surfaceLight.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Search Capabilities',
              style: GoogleFonts.inter(
                color: AppColors.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildOptionTile(
            context,
            icon: LucideIcons.globe,
            title: 'Web Search',
            subtitle: 'Real-time information from the web',
            isActive: isWebSearchEnabled,
            onTap: onWebSearchToggle,
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isWebSearchEnabled ? 1.0 : 0.5,
            child: IgnorePointer(
              ignoring: !isWebSearchEnabled,
              child: Container(
                decoration: BoxDecoration(
                  color: isDeepSearchEnabled
                      ? AppColors.accent.withValues(alpha: 0.05)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isDeepSearchEnabled
                      ? Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2),
                        )
                      : Border.all(color: Colors.transparent),
                ),
                child: _buildOptionTile(
                  context,
                  icon: LucideIcons.layers,
                  title: 'Deep Search',
                  subtitle: 'Comprehensive analysis & full page reading',
                  isActive: isDeepSearchEnabled,
                  activeColor: AppColors.accent,
                  onTap: onDeepSearchToggle,
                  isSubOption: true,
                ),
              ),
            ),
          ),
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
    bool isSubOption = false,
  }) {
    final color = activeColor ?? AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withValues(alpha: 0.1)
                      : AppColors.surfaceLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isActive ? color : AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            color: isActive ? color : AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Icon(
                            LucideIcons.checkCircle2,
                            size: 14,
                            color: color,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: AppColors.secondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isActive)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surfaceLight,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
