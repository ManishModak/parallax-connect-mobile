import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/haptics_helper.dart';

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
        color: isActive
            ? AppColors.surface
            : AppColors.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: isActive
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              )
            : Border.all(
                color: AppColors.secondary.withValues(alpha: 0.05),
                width: 1,
              ),
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
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (isImportant)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      LucideIcons.star,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.secondary,
                          fontSize: 15,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: GoogleFonts.inter(
                          color: AppColors.secondary.withValues(alpha: 0.6),
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
                    size: 18,
                    color: AppColors.secondary.withValues(alpha: 0.5),
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
                      value: 'important',
                      child: Row(
                        children: [
                          Icon(
                            isImportant ? LucideIcons.starOff : LucideIcons.star,
                            size: 16,
                            color: isImportant ? AppColors.secondary : Colors.amber,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isImportant ? 'Unmark Important' : 'Mark Important',
                            style: GoogleFonts.inter(
                              color: AppColors.secondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.edit2,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Rename',
                            style: GoogleFonts.inter(
                              color: AppColors.secondary,
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
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Export PDF',
                            style: GoogleFonts.inter(
                              color: AppColors.secondary,
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
                            color: AppColors.error.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Delete',
                            style: GoogleFonts.inter(
                              color: AppColors.error.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'important') {
                      if (onToggleImportant != null) {
                        onToggleImportant!();
                      }
                    } else if (value == 'delete') {
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
