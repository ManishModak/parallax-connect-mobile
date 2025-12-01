import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../app/constants/app_colors.dart';
import '../services/server/feature_flags_service.dart';

/// Helper to show snackbars for disabled features
class FeatureSnackbar {
  /// Show a snackbar explaining why a feature is disabled
  static void showDisabled(
    BuildContext context, {
    required String featureName,
    required FeatureStatus status,
    VoidCallback? onSettingsTap,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(LucideIcons.lock, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$featureName is disabled',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Enable in Settings to use this feature',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.2)),
        ),
        duration: const Duration(seconds: 4),
        action: onSettingsTap != null
            ? SnackBarAction(
                label: 'Settings',
                textColor: AppColors.primary,
                onPressed: onSettingsTap,
              )
            : null,
      ),
    );
  }

  /// Show a simple info snackbar
  static void showInfo(
    BuildContext context, {
    required String message,
    IconData icon = LucideIcons.info,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: AppColors.primary),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show a success snackbar
  static void showSuccess(
    BuildContext context, {
    required String message,
    IconData icon = LucideIcons.checkCircle,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: AppColors.primary),
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.2)),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show an error snackbar
  static void showError(
    BuildContext context, {
    required String message,
    IconData icon = LucideIcons.alertCircle,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: AppColors.error),
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
