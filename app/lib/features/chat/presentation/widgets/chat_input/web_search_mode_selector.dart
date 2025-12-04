import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../../core/utils/haptics_helper.dart';
import '../../view_models/chat_controller.dart';

class WebSearchModeSelector extends ConsumerWidget {
  const WebSearchModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only listen to the webSearchMode field so that other ChatState changes
    // (streaming, messages, errors, etc.) don't cause this widget to rebuild.
    final mode = ref.watch(
      chatControllerProvider.select((state) => state.webSearchMode),
    );
    final isActive = mode != 'off';

    String label = 'Web Search';
    IconData icon = LucideIcons.globe;

    switch (mode) {
      case 'normal':
        label = 'Normal Search';
        icon = LucideIcons.globe;
        break;
      case 'deep':
        label = 'Deep Search';
        icon = LucideIcons.globe;
        break;
      case 'deeper':
        label = 'Deeper Search';
        icon = LucideIcons.layers;
        break;
      case 'off':
        label = 'Search Off';
        icon = LucideIcons.globe;
        break;
    }

    return PopupMenuButton<String>(
      offset: const Offset(0, -260), // Adjust to show above
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.surface,
      elevation: 4,
      onSelected: (value) {
        ref.read(hapticsHelperProvider).triggerHaptics();
        ref.read(chatControllerProvider.notifier).setWebSearchMode(value);
        // Keep keyboard dismissed after selection
        FocusScope.of(context).unfocus();
      },
      onCanceled: () {
        // Keep keyboard dismissed when menu is cancelled
        FocusScope.of(context).unfocus();
      },
      onOpened: () {
        ref.read(hapticsHelperProvider).triggerHaptics();
        // Dismiss keyboard when menu opens
        FocusScope.of(context).unfocus();
      },
      itemBuilder: (context) => [
        _buildMenuItem(
          'deep',
          'Deep Search',
          'Comprehensive (Default)',
          LucideIcons.globe,
        ),
        _buildMenuItem(
          'normal',
          'Normal Search',
          'Fast check',
          LucideIcons.zap,
        ),
        _buildMenuItem(
          'deeper',
          'Deeper Search',
          'Thorough reading',
          LucideIcons.layers,
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          'off',
          'Turn Off',
          'Disable web search',
          LucideIcons.globe,
          isDestructive: true,
        ),
      ],
      child: Container(
        height: 36,
        padding: EdgeInsets.symmetric(horizontal: isActive ? 12 : 0),
        width: isActive ? null : 36,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceLight.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? AppColors.primary
                  : AppColors.secondary.withValues(alpha: 0.5),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    String title,
    String subtitle,
    IconData icon, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDestructive ? AppColors.error : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: isDestructive ? AppColors.error : AppColors.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.secondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
