import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSubmitted;
  final bool isLoading;

  const ChatInput({
    super.key,
    required this.onSubmitted,
    this.isLoading = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();

  void _handleSubmit() {
    if (_controller.text.trim().isEmpty || widget.isLoading) return;
    widget.onSubmitted(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.accent)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.accent),
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.inter(color: AppColors.primary),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSubmit(),
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle: GoogleFonts.inter(color: AppColors.secondary),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _handleSubmit,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isLoading ? AppColors.surface : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.secondary,
                      ),
                    )
                  : const Icon(
                      LucideIcons.arrowUp,
                      color: AppColors.background,
                      size: 24,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
