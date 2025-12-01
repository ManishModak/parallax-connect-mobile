import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../../core/utils/haptics_helper.dart';

class RenameDialog extends ConsumerStatefulWidget {
  final String currentTitle;
  final Function(String) onRename;

  const RenameDialog({
    super.key,
    required this.currentTitle,
    required this.onRename,
  });

  @override
  ConsumerState<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends ConsumerState<RenameDialog> {
  late TextEditingController _controller;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTitle);
    _controller.addListener(_validate);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final isValid = _controller.text.trim().isNotEmpty;
    if (isValid != _isValid) {
      setState(() {
        _isValid = isValid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.edit2, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Rename Chat',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autofocus: true,
              style: GoogleFonts.inter(color: AppColors.primary, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Enter chat title',
                hintStyle: GoogleFonts.inter(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) {
                if (_isValid) {
                  ref.read(hapticsHelperProvider).triggerHaptics();
                  widget.onRename(_controller.text.trim());
                  context.pop();
                }
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    ref.read(hapticsHelperProvider).triggerHaptics();
                    context.pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isValid
                      ? () {
                          ref.read(hapticsHelperProvider).triggerHaptics();
                          widget.onRename(_controller.text.trim());
                          context.pop();
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.3,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
