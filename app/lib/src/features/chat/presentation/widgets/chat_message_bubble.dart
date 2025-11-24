import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import '../../../../core/constants/app_colors.dart';
import '../chat_controller.dart';

class ChatMessageBubble extends StatefulWidget {
  final ChatMessage? message;
  final bool isShimmer;

  const ChatMessageBubble({super.key, this.message, this.isShimmer = false});

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  bool _copiedAll = false;
  final Map<String, bool> _copiedCode = {};

  void _copyToClipboard(String text, {String? codeKey}) async {
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

    final isUser = widget.message!.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (widget.message!.text.isNotEmpty)
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding: isUser
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                  : EdgeInsets.zero,
              decoration: isUser
                  ? BoxDecoration(
                      color: AppColors.userBubbleBackground,
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null,
              child: MarkdownBody(
                data: widget.message!.text,
                selectable: true,
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
                    backgroundColor: Colors.white10,
                    fontSize: 14,
                  ),
                  // Removed codeblockDecoration - using custom code builder
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
            ),
          if (widget.message!.attachmentPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.message!.attachmentPaths.map((path) {
                final isImage =
                    path.toLowerCase().endsWith('.jpg') ||
                    path.toLowerCase().endsWith('.jpeg') ||
                    path.toLowerCase().endsWith('.png') ||
                    path.toLowerCase().endsWith('.webp');

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
          // Copy All button for bot messages
          if (!isUser && widget.message!.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _copyToClipboard(widget.message!.text),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _copiedAll
                      ? AppColors.accent.withOpacity(0.2)
                      : AppColors.surfaceLight.withOpacity(0.3),
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
                      size: 14,
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShimmerBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Shimmer.fromColors(
          baseColor: const Color(0xFF2A2A2A),
          highlightColor: const Color(0xFF4A4A4A),
          child: Container(
            width: 200,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final Function(String) onCopy;
  final bool Function(String) isCopied;

  CodeElementBuilder({required this.onCopy, required this.isCopied});

  String _detectLanguage(md.Element element) {
    // Try to get language from info string (e.g., ```python)
    if (element.attributes['class'] != null) {
      final classes = element.attributes['class']!.split(' ');
      for (var className in classes) {
        if (className.startsWith('language-')) {
          return className.substring(9); // Remove 'language-' prefix
        }
      }
    }

    // Fallback: try to detect from parent element
    final parent = element.children?.first;
    if (parent is md.Element && parent.attributes['class'] != null) {
      final classes = parent.attributes['class']!.split(' ');
      for (var className in classes) {
        if (className.startsWith('language-')) {
          return className.substring(9);
        }
      }
    }

    return 'plaintext'; // Default fallback
  }

  String _getLanguageDisplayName(String lang) {
    final langMap = {
      'js': 'javascript',
      'ts': 'typescript',
      'py': 'python',
      'rb': 'ruby',
      'cpp': 'c++',
      'cs': 'csharp',
      'md': 'markdown',
      'yml': 'yaml',
      'sh': 'bash',
      'kt': 'kotlin',
      'swift': 'swift',
      'go': 'go',
      'rs': 'rust',
      'java': 'java',
      'dart': 'dart',
      'html': 'html',
      'css': 'css',
      'json': 'json',
      'xml': 'xml',
      'sql': 'sql',
      'plaintext': 'text',
    };

    return langMap[lang.toLowerCase()] ?? lang;
  }

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String code = element.textContent;

    // Handle code blocks (can be wrapped in pre or be a code element with newlines)
    if (element.tag == 'pre' ||
        (element.tag == 'code' && code.contains('\n'))) {
      final language = _detectLanguage(element);
      final displayName = _getLanguageDisplayName(language);

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language label and copy button header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    displayName.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  InkWell(
                    onTap: () => onCopy(code),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCopied(code)
                            ? AppColors.accent.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isCopied(code)
                              ? AppColors.accent
                              : Colors.white10,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCopied(code)
                                ? LucideIcons.check
                                : LucideIcons.copy,
                            size: 12,
                            color: isCopied(code)
                                ? AppColors.accent
                                : AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCopied(code) ? 'Copied!' : 'Copy',
                            style: GoogleFonts.inter(
                              color: isCopied(code)
                                  ? AppColors.accent
                                  : AppColors.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Code content with syntax highlighting
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: HighlightView(
                code,
                language: language,
                theme: atomOneDarkTheme,
                padding: EdgeInsets.zero,
                textStyle: GoogleFonts.firaCode(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    // Handle inline code (short code without newlines)
    if (element.tag == 'code') {
      return null; // Let default styling handle inline code
    }

    return null;
  }
}
