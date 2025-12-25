import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../../core/utils/haptics_helper.dart';
import '../../../models/chat_message.dart';
import '../../../utils/file_type_helper.dart';
import '../indicators/sources_pill.dart';
import '../indicators/thinking_pill.dart';
import '../sheets/search_results_sheet.dart';
import '../sheets/thinking_details_sheet.dart';
import 'code_block_builder.dart';

class ChatMessageBubble extends ConsumerStatefulWidget {
  final ChatMessage? message;
  final bool isShimmer;
  final VoidCallback? onEdit;
  final VoidCallback? onRetry;

  const ChatMessageBubble({
    super.key,
    this.message,
    this.isShimmer = false,
    this.onEdit,
    this.onRetry,
  });

  @override
  ConsumerState<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends ConsumerState<ChatMessageBubble> {
  bool _copiedAll = false;
  bool _showOptions = false;
  final Map<String, bool> _copiedCode = {};

  // Cached MarkdownStyleSheet to avoid recreating TextStyles on every rebuild
  static final MarkdownStyleSheet _markdownStyleSheet = MarkdownStyleSheet(
    p: GoogleFonts.inter(color: AppColors.primary, fontSize: 16, height: 1.5),
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
      border: Border(left: BorderSide(color: AppColors.accent, width: 4)),
    ),
  );

  void _copyToClipboard(String text, {String? codeKey}) async {
    ref.read(hapticsHelperProvider).triggerHaptics();
    await Clipboard.setData(ClipboardData(text: text));
    setState(() {
      if (codeKey != null) {
        _copiedCode[codeKey] = true;
      } else {
        _copiedAll = true;
      }
    });

    // Reset after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          if (codeKey != null) {
            _copiedCode[codeKey] = false;
          } else {
            _copiedAll = false;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isShimmer) {
      return _buildShimmerBubble();
    }

    final message = widget.message;
    if (message == null) {
      return const SizedBox.shrink();
    }

    final isUser = message.isUser;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (message.text.isNotEmpty)
            Container(
              // User messages: constrained width with bubble styling
              // Bot messages: full width (code blocks extend, text wraps naturally)
              constraints: isUser
                  ? BoxConstraints(maxWidth: screenWidth * 0.8)
                  : null,
              padding: isUser
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                  : EdgeInsets.zero,
              decoration: isUser
                  ? BoxDecoration(
                      color: AppColors.userBubbleBackground,
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null,
              child: GestureDetector(
                onTap: isUser
                    ? () {
                        setState(() {
                          _showOptions = !_showOptions;
                        });
                      }
                    : null,
                child: MarkdownBody(
                  data: message.text,
                  selectable:
                      !isUser, // Only selectable if not user (user taps to toggle options)
                  builders: {
                    'code': CodeElementBuilder(
                      onCopy: (code) => _copyToClipboard(
                        code,
                        codeKey: code.hashCode.toString(),
                      ),
                      isCopied: (code) =>
                          _copiedCode[code.hashCode.toString()] ?? false,
                    ),
                  },
                  styleSheet: _markdownStyleSheet,
                ),
              ),
            ),
          if (message.attachmentPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.attachmentPaths.map((path) {
                final isImage = FileTypeHelper.isImageFile(path);

                return Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isImage
                      ? Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                LucideIcons.image,
                                color: AppColors.secondary,
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Icon(
                            LucideIcons.file,
                            color: AppColors.secondary,
                            size: 32,
                          ),
                        ),
                );
              }).toList(),
            ),
          ],
          // User Message Actions (Edit, Retry) - Tap to reveal
          if (isUser)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showOptions
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionIcon(
                            icon: LucideIcons.pencil,
                            tooltip: 'Edit',
                            onTap: widget.onEdit ?? () {},
                          ),
                          const SizedBox(width: 8),
                          _buildActionIcon(
                            icon: LucideIcons.refreshCw,
                            tooltip: 'Retry',
                            onTap: widget.onRetry ?? () {},
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

          // Bot Message Extras (Thinking & Search)
          if (!isUser &&
              ((message.thinkingContent != null &&
                      message.thinkingContent!.isNotEmpty) ||
                  (message.searchMetadata != null &&
                      message.searchMetadata!['results'] != null))) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (message.thinkingContent != null &&
                    message.thinkingContent!.isNotEmpty) ...[
                  ThinkingPill(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => ThinkingDetailsSheet(
                          thinkingContent: message.thinkingContent!,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                if (message.searchMetadata != null &&
                    message.searchMetadata!['results'] != null)
                  Builder(
                    builder: (context) {
                      final results =
                          message.searchMetadata!['results'] as List;
                      return SourcesPill(
                        sourceCount: results.length,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) =>
                                SearchResultsSheet(results: results),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ],
          // Copy All button for bot messages
          if (!isUser && message.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: 'Copy entire message to clipboard',
              child: InkWell(
                onTap: () => _copyToClipboard(message.text),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _copiedAll
                      ? AppColors.accent.withValues(alpha: 0.2)
                      : AppColors.surfaceLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _copiedAll
                        ? AppColors.accent
                        : AppColors.surfaceLight,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _copiedAll ? LucideIcons.check : LucideIcons.copy,
                      size: 16,
                      color: _copiedAll
                          ? AppColors.accent
                          : AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _copiedAll ? 'Copied!' : 'Copy All',
                      style: GoogleFonts.inter(
                        color: _copiedAll
                            ? AppColors.accent
                            : AppColors.secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          ref.read(hapticsHelperProvider).triggerHaptics();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.secondary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          label: 'AI is thinking...',
          child: Shimmer.fromColors(
            baseColor: AppColors.shimmerBase,
            highlightColor: AppColors.shimmerHighlight,
            child: Container(
              width: 200,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
