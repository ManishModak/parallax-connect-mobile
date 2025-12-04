import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:parallax_connect/app/constants/app_colors.dart';
import 'package:parallax_connect/core/utils/haptics_helper.dart';

class HistoryItemTile extends ConsumerStatefulWidget {
  final String title;
  final String time;
  final bool isActive;
  final bool isImportant;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Function(String newTitle)? onRename;
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

  @override
  ConsumerState<HistoryItemTile> createState() => _HistoryItemTileState();
}

class _HistoryItemTileState extends ConsumerState<HistoryItemTile> {
  bool _isRenaming = false;
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.title);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant HistoryItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.title != oldWidget.title && !_isRenaming) {
      _textController.text = widget.title;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isRenaming) {
      _submitRename();
    }
  }

  void _startRenaming() {
    setState(() {
      _isRenaming = true;
    });
    _focusNode.requestFocus();
  }

  void _submitRename() {
    if (_textController.text.trim().isNotEmpty &&
        _textController.text != widget.title) {
      widget.onRename?.call(_textController.text.trim());
    } else {
      // Revert if empty or unchanged
      _textController.text = widget.title;
    }
    setState(() {
      _isRenaming = false;
    });
  }

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
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.isActive ? AppColors.surfaceLight : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: widget.isActive
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
            if (_isRenaming) {
              _submitRename();
              return;
            }
            ref.read(hapticsHelperProvider).triggerHaptics();
            widget.onTap?.call();
            if (widget.onTap == null) {
              context.pop();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (widget.isActive)
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
                      if (_isRenaming)
                        TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: widget.isActive
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _submitRename(),
                        )
                      else
                        Text(
                          widget.title,
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: widget.isActive
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        widget.time,
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
                    size: 20,
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
                      if (widget.onDelete != null) {
                        widget.onDelete!();
                      } else {
                        _showSnackBar(context, 'Delete feature coming soon');
                      }
                    } else if (value == 'rename') {
                      _startRenaming();
                    } else if (value == 'export') {
                      if (widget.onExport != null) {
                        widget.onExport!();
                      } else {
                        _showSnackBar(context, 'Export feature coming soon');
                      }
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    widget.isImportant ? Icons.star : LucideIcons.star,
                    size: 20,
                    color: widget.isImportant
                        ? Colors.amber
                        : AppColors.secondary.withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    ref.read(hapticsHelperProvider).triggerHaptics();
                    widget.onToggleImportant?.call();
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
