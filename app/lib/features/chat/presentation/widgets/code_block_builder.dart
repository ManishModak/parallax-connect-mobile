import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import '../../../../app/constants/app_colors.dart';

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

      // Code block - takes full available width
      return Container(
        decoration: BoxDecoration(
          color: AppColors.codeBlockBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.codeBlockBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language label and copy button header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.codeBlockBorder),
                ),
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
                            ? AppColors.accent.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isCopied(code)
                              ? AppColors.accent
                              : AppColors.codeBlockBorder,
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

