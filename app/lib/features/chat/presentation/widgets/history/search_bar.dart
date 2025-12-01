import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';

typedef HistorySearchChanged = void Function(String value, Timer? existingTimer);

class HistorySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final HistorySearchChanged onChangedWithDebounce;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final Timer? debounceTimer;

  const HistorySearchBar({
    super.key,
    required this.controller,
    required this.isSearching,
    required this.onChangedWithDebounce,
    required this.onClear,
    required this.onClose,
    required this.debounceTimer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: controller,
                onChanged: (value) => onChangedWithDebounce(value, debounceTimer),
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search chat history',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.secondary,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    LucideIcons.search,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? isSearching
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                LucideIcons.x,
                                color: AppColors.secondary,
                                size: 18,
                              ),
                              tooltip: 'Clear search',
                              onPressed: onClear,
                            )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(LucideIcons.x, color: AppColors.secondary),
            tooltip: 'Close history',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}


