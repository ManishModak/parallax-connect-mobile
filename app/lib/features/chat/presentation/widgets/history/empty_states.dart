import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';

class HistoryEmptyState extends StatelessWidget {
  const HistoryEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.messageSquare,
            size: 48,
            color: AppColors.secondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No chat history',
            style: GoogleFonts.inter(
              color: AppColors.secondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new chat to see it here',
            style: GoogleFonts.inter(
              color: AppColors.secondary.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class HistorySearchEmptyState extends StatelessWidget {
  const HistorySearchEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.searchX,
            size: 48,
            color: AppColors.secondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No chats found',
            style: GoogleFonts.inter(
              color: AppColors.secondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: GoogleFonts.inter(
              color: AppColors.secondary.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}


