import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:parallax_connect/app/constants/app_colors.dart';
import 'package:parallax_connect/core/utils/haptics_helper.dart';

class HistoryItemTile extends ConsumerWidget {
  final String title;
  final String time;
  final bool isActive;
  final bool isImportant;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onExport;
  final VoidCallback? onToggleImportant;

  const HistoryItemTile({
    super.key,
    required this.title,
    required this.time,
    this.isActive = false,
    this.isImportant = false,
    this.onTap,
    this.onDelete,
    this.onRename,
    this.onExport,
    this.onToggleImportant,
  });

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.surfaceLight : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(hapticsHelperProvider).triggerHaptics();
            onTap?.call();
            if (onTap == null) {
              context.pop();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (isActive)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: GoogleFonts.inter(
                          color: AppColors.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    LucideIcons.moreVertical,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                    ),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.edit2,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Rename',
                            style: GoogleFonts.inter(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.share,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Export PDF',
                            style: GoogleFonts.inter(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.trash2,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Delete',
                            style: GoogleFonts.inter(
                              color: AppColors.error,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      if (onDelete != null) {
                        onDelete!();
                      } else {
                        _showSnackBar(context, 'Delete feature coming soon');
                      }
                    } else if (value == 'rename') {
                      if (onRename != null) {
                        onRename!();
                      } else {
                        _showSnackBar(context, 'Rename feature coming soon');
                      }
                    } else if (value == 'export') {
                      if (onExport != null) {
                        onExport!();
                      } else {
                        _showSnackBar(context, 'Export feature coming soon');
                      }
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    isImportant ? LucideIcons.star : LucideIcons.star,
                    size: 18,
                    color: isImportant
                        ? Colors.amber
                        : AppColors.secondary.withValues(alpha: 0.5),
                    fill: isImportant ? 1.0 : 0.0,
                  ),
                  onPressed: () {
                    ref.read(hapticsHelperProvider).triggerHaptics();
                    onToggleImportant?.call();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
