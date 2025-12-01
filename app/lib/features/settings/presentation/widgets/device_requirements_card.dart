import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../core/services/system/device_requirements_service.dart';

/// Card showing device info and feature compatibility
class DeviceRequirementsCard extends ConsumerWidget {
  const DeviceRequirementsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceInfoAsync = ref.watch(deviceInfoProvider);
    final compatibilityAsync = ref.watch(featureCompatibilityProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.smartphone,
              color: AppColors.accent,
              size: 20,
            ),
          ),
          title: Text(
            'Device Compatibility',
            style: GoogleFonts.inter(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: deviceInfoAsync.when(
            loading: () => Text(
              'Checking device...',
              style: GoogleFonts.inter(
                color: AppColors.secondary,
                fontSize: 13,
              ),
            ),
            error: (_, __) => Text(
              'Unable to detect device',
              style: GoogleFonts.inter(color: AppColors.error, fontSize: 13),
            ),
            data: (info) => Text(
              '${info.deviceModel} • ${info.ramDisplay} RAM',
              style: GoogleFonts.inter(
                color: AppColors.secondary,
                fontSize: 13,
              ),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            // Device Info Section
            deviceInfoAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => _buildErrorState(e.toString()),
              data: (info) => _buildDeviceInfoSection(info),
            ),
            const SizedBox(height: 16),
            // Feature Compatibility Section
            compatibilityAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (compatibility) =>
                  _buildCompatibilitySection(compatibility),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoSection(DeviceInfo info) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Device',
            style: GoogleFonts.inter(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(LucideIcons.smartphone, 'Model', info.deviceModel),
          const SizedBox(height: 8),
          _buildInfoRow(LucideIcons.settings, 'OS', info.osVersion),
          const SizedBox(height: 8),
          _buildInfoRow(LucideIcons.cpu, 'RAM', info.ramDisplay),
          if (info.isLowEndDevice) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.alertCircle,
                    color: AppColors.accent,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Low-end device detected. Some features may run slowly.',
                      style: GoogleFonts.inter(
                        color: AppColors.accent,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondary, size: 14),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompatibilitySection(
    Map<String, RequirementCheckResult> compatibility,
  ) {
    final features = DeviceRequirementsService.featureRequirements;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feature Requirements',
            style: GoogleFonts.inter(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...features.entries.map((entry) {
            final result = compatibility[entry.key];
            final req = entry.value;
            return _buildFeatureRequirementRow(req, result);
          }),
        ],
      ),
    );
  }

  Widget _buildFeatureRequirementRow(
    FeatureRequirements req,
    RequirementCheckResult? result,
  ) {
    final isCompatible = result?.meetsRequirements ?? true;
    final hasWarnings = result?.warnings.isNotEmpty ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompatible
                      ? (hasWarnings ? AppColors.accent : AppColors.successDark)
                      : AppColors.error,
                ),
                child: Icon(
                  isCompatible
                      ? (hasWarnings
                            ? LucideIcons.alertCircle
                            : LucideIcons.check)
                      : LucideIcons.x,
                  color: Colors.white,
                  size: 12,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.featureName,
                      style: GoogleFonts.inter(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Min ${_formatRam(req.minRamMb)} RAM',
                      style: GoogleFonts.inter(
                        color: AppColors.secondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompatible
                      ? AppColors.successDark.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isCompatible ? 'Compatible' : 'Limited',
                  style: GoogleFonts.inter(
                    color: isCompatible
                        ? AppColors.successDark
                        : AppColors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // Show issues if any
          if (result != null && result.issues.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...result.issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(left: 30, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.alertTriangle,
                      color: AppColors.error,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        issue,
                        style: GoogleFonts.inter(
                          color: AppColors.error,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not detect device info',
              style: GoogleFonts.inter(color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRam(int mb) {
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(0)}GB';
    }
    return '${mb}MB';
  }
}
