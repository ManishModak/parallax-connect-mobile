import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../../core/services/model_selection_service.dart';
import '../../../../../core/utils/haptics_helper.dart';

/// Model selector widget showing active model
class ModelSelector extends ConsumerWidget {
  const ModelSelector({super.key});

  void _showModelInfoSnackbar(
    BuildContext context,
    ModelSelectionState modelState,
  ) {
    final activeModel = modelState.activeModel;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              modelState.hasActiveModel
                  ? LucideIcons.cpu
                  : LucideIcons.alertCircle,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modelState.hasActiveModel
                        ? activeModel!.name
                        : 'No model running',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Change model in Parallax Web UI',
                    style: GoogleFonts.inter(
                      color: AppColors.primaryMildVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: modelState.hasActiveModel
            ? AppColors.surfaceLight
            : AppColors.warning.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(modelSelectionProvider);
    final activeModel = modelState.activeModel;

    final displayName = activeModel?.name ?? 'No Model';
    final shortName = displayName.contains('/')
        ? displayName.split('/').last
        : displayName;

    return GestureDetector(
      onTap: () {
        ref.read(hapticsHelperProvider).triggerHaptics();
        _showModelInfoSnackbar(context, modelState);
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: modelState.hasActiveModel
              ? AppColors.surfaceLight.withValues(alpha: 0.5)
              : AppColors.warning.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.cpu,
              size: 14,
              color: modelState.hasActiveModel
                  ? AppColors.secondary
                  : AppColors.warning,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                shortName,
                style: GoogleFonts.inter(
                  color: modelState.hasActiveModel
                      ? AppColors.secondary
                      : AppColors.warning,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

