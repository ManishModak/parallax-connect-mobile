import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../view_models/chat_controller.dart';

class WebSearchModeSelector extends ConsumerWidget {
  final VoidCallback onTap;

  const WebSearchModeSelector({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Tooltip(
      message: 'Web Search Mode: $label',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surfaceLight.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.surfaceLight, width: 1),
          ),
          child: Semantics(
            button: true,
            label: 'Web Search Mode: $label',
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 36,
                padding: EdgeInsets.symmetric(horizontal: isActive ? 12 : 0),
                width: isActive ? null : 36,
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
            ),
          ),
          ),
        ),
      ),
    );
  }
}
