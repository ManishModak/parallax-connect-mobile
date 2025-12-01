import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../../app/constants/app_colors.dart';
import 'code_block_builder.dart';

/// A widget that displays streaming content as it arrives
class StreamingMessageBubble extends StatelessWidget {
  final String content;
  final bool isComplete;

  const StreamingMessageBubble({
    super.key,
    required this.content,
    this.isComplete = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.isNotEmpty)
            MarkdownBody(
              data: content,
              selectable: false,
              builders: {
                'code': CodeElementBuilder(
                  onCopy: (_) {},
                  isCopied: (_) => false,
                ),
              },
              styleSheet: MarkdownStyleSheet(
                p: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 16,
                  height: 1.5,
                ),
                strong: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
                em: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontStyle: FontStyle.italic,
                ),
                h1: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                h2: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                h3: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                code: GoogleFonts.firaCode(
                  color: AppColors.primary,
                  backgroundColor: AppColors.codeBlockBorder,
                  fontSize: 14,
                ),
                blockquote: GoogleFonts.inter(
                  color: AppColors.secondary,
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.accent, width: 4),
                  ),
                ),
              ),
            ),
          // Cursor indicator when streaming
          if (!isComplete)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _StreamingCursor(),
            ),
        ],
      ),
    );
  }
}

class _StreamingCursor extends StatefulWidget {
  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
