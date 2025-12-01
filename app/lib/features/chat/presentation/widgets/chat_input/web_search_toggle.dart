import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../../app/routes/app_router.dart';
import '../../../../../core/services/server/feature_flags_service.dart';
import '../../../../../core/utils/feature_snackbar.dart';
import '../../../../../core/utils/haptics_helper.dart';
import '../../../../settings/presentation/view_models/settings_controller.dart';

/// Web search toggle widget
class WebSearchToggle extends ConsumerStatefulWidget {
  final VoidCallback onLongPress;

  const WebSearchToggle({super.key, required this.onLongPress});

  @override
  ConsumerState<WebSearchToggle> createState() => _WebSearchToggleState();
}

class _WebSearchToggleState extends ConsumerState<WebSearchToggle> {
  bool _isSearchActive = false;

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsControllerProvider);
    final isFeatureEnabled = settingsState.isWebSearchEnabled;
    final depth = settingsState.webSearchDepth;

    String label = 'Web Search';
    IconData icon = LucideIcons.globe;

    if (depth == 'deep') {
      label = 'Deep Search';
      icon = LucideIcons.globe;
    } else if (depth == 'deeper') {
      label = 'Deeper Search';
      icon = LucideIcons.layers;
    }

    return GestureDetector(
      onTap: () {
        if (!isFeatureEnabled) {
          ref.read(hapticsHelperProvider).triggerHaptics();
          FeatureSnackbar.showDisabled(
            context,
            featureName: 'Web Search',
            status: FeatureStatus.available(),
            onSettingsTap: () => context.push(AppRoutes.settings),
          );
          return;
        }

        ref.read(hapticsHelperProvider).triggerHaptics();
        setState(() {
          _isSearchActive = !_isSearchActive;
        });
      },
      onLongPress: () {
        if (!isFeatureEnabled) return;
        ref.read(hapticsHelperProvider).triggerHaptics();
        widget.onLongPress();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        padding: EdgeInsets.symmetric(horizontal: _isSearchActive ? 12 : 0),
        width: _isSearchActive ? null : 36,
        decoration: BoxDecoration(
          color: isFeatureEnabled
              ? (_isSearchActive
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.surfaceLight.withValues(alpha: 0.2))
              : AppColors.surfaceLight.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isFeatureEnabled
                  ? (_isSearchActive
                        ? AppColors.primary
                        : AppColors.secondary.withValues(alpha: 0.5))
                  : AppColors.secondary.withValues(alpha: 0.2),
            ),
            if (_isSearchActive) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
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
}
