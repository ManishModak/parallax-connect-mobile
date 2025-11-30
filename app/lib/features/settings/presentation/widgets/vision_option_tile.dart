import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/constants/app_colors.dart';

class VisionOptionTile extends StatelessWidget {
  final String title;
  final String description;
  final String? techNote;
  final String value;
  final String groupValue;
  final ValueChanged<String?>? onChanged;

  const VisionOptionTile({
    super.key,
    required this.title,
    required this.description,
    this.techNote,
    required this.value,
    required this.groupValue,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final isDisabled = onChanged == null;
    return Semantics(
      label: '$title option',
      toggled: isSelected,
      button: true,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.05)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.secondary.withValues(alpha: 0.1),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isDisabled ? null : () => onChanged!(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RadioIndicator(isSelected: isSelected),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primaryMildVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.inter(
                            color: AppColors.secondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        if (techNote != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Text(
                              techNote!,
                              style: GoogleFonts.inter(
                                color: AppColors.secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  final bool isSelected;

  const _RadioIndicator({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.secondary,
          width: 2,
        ),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
