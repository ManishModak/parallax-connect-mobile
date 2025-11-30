import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';

class HapticsSelector extends StatelessWidget {
  final String currentLevel;
  final ValueChanged<String> onLevelSelected;
  final VoidCallback? onHapticFeedback;

  const HapticsSelector({
    super.key,
    required this.currentLevel,
    required this.onLevelSelected,
    this.onHapticFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HapticTile(
          label: 'None',
          value: 'none',
          icon: LucideIcons.smartphone,
          isSelected: currentLevel == 'none',
          onTap: _handleSelection,
        ),
        const SizedBox(width: 12),
        _HapticTile(
          label: 'Min',
          value: 'min',
          icon: LucideIcons.vibrate,
          isSelected: currentLevel == 'min',
          onTap: _handleSelection,
        ),
        const SizedBox(width: 12),
        _HapticTile(
          label: 'Max',
          value: 'max',
          icon: LucideIcons.waves,
          isSelected: currentLevel == 'max',
          onTap: _handleSelection,
        ),
      ],
    );
  }

  void _handleSelection(String value) {
    if (value == currentLevel) return;
    onHapticFeedback?.call();
    onLevelSelected(value);
  }
}

class _HapticTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isSelected;
  final ValueChanged<String> onTap;

  const _HapticTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(value),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.secondary.withValues(alpha: 0.1),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppColors.primary : AppColors.secondary,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isSelected ? AppColors.primary : AppColors.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
