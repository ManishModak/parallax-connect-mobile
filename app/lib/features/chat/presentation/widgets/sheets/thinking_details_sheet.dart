import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/constants/app_colors.dart';

class ThinkingDetailsSheet extends StatefulWidget {
  final String thinkingContent;

  const ThinkingDetailsSheet({super.key, required this.thinkingContent});

  @override
  State<ThinkingDetailsSheet> createState() => _ThinkingDetailsSheetState();
}

class _ThinkingDetailsSheetState extends State<ThinkingDetailsSheet> {
  final ScrollController _contentController = ScrollController();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.66,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, sheetController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle & Header (Draggable)
              SingleChildScrollView(
                controller: sheetController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Text(
                        'Thought Process',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content (Independent Scroll)
              Expanded(
                child: SingleChildScrollView(
                  controller: _contentController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: MarkdownBody(
                    data: widget.thinkingContent,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        color: AppColors.secondary,
                        height: 1.5,
                      ),
                      code: GoogleFonts.jetBrainsMono(
                        backgroundColor: AppColors.surfaceLight.withValues(
                          alpha: 0.5,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
