import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/constants/app_colors.dart';

class ConnectionModeToggle extends StatelessWidget {
  final bool isLocal;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback? onHapticFeedback;

  const ConnectionModeToggle({
    super.key,
    required this.isLocal,
    required this.onModeChanged,
    this.onHapticFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: 'Cloud (Ngrok)',
            isSelected: !isLocal,
            onTap: () => _handleSelection(false),
          ),
          _ModeButton(
            label: 'Local (LAN)',
            isSelected: isLocal,
            onTap: () => _handleSelection(true),
          ),
        ],
      ),
    );
  }

  void _handleSelection(bool local) {
    if (local == isLocal) return;
    onHapticFeedback?.call();
    onModeChanged(local);
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? AppColors.primary : AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

