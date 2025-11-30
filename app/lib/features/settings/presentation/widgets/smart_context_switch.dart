import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/constants/app_colors.dart';

class SmartContextSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SmartContextSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
        inactiveThumbColor: AppColors.secondary,
        inactiveTrackColor: AppColors.background,
        title: Text(
          'Smart Context Window',
          style: GoogleFonts.inter(
            color: AppColors.primaryMildVariant,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Automatically uses RAG mode for large documents or when needed.',
            style: GoogleFonts.inter(
              color: AppColors.secondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
