import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../../core/services/system/device_requirements_service.dart';
import '../../../../../core/utils/haptics_helper.dart';

/// Helper class for checking device requirements and showing warnings
class RequirementsChecker {
  /// Shows a warning dialog if device doesn't meet requirements
  static Future<bool> checkAndWarnRequirements(
    BuildContext context,
    WidgetRef ref,
    String featureKey,
    HapticsHelper hapticsHelper,
  ) async {
    final service = ref.read(deviceRequirementsServiceProvider);
    final result = await service.checkRequirements(featureKey);

    if (!result.meetsRequirements) {
      hapticsHelper.triggerHaptics();
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                LucideIcons.alertTriangle,
                color: AppColors.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Device Requirements',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your device may not meet the requirements for this feature:',
                style: GoogleFonts.inter(
                  color: AppColors.secondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ...result.issues.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.x, color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          issue,
                          style: GoogleFonts.inter(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (result.recommendation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  result.recommendation,
                  style: GoogleFonts.inter(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: AppColors.secondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Enable Anyway',
                style: GoogleFonts.inter(color: AppColors.accent),
              ),
            ),
          ],
        ),
      );
      return proceed ?? false;
    }

    // Show warnings if any (but still allow enabling)
    if (result.warnings.isNotEmpty) {
      final deviceInfo = await service.getDeviceInfo();
      if (deviceInfo.isLowEndDevice) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Note: This feature may run slowly on your device',
              style: GoogleFonts.inter(color: AppColors.primary),
            ),
            backgroundColor: AppColors.surface,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    return true;
  }
}
