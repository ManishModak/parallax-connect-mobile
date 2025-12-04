import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../storage/models/chat_session.dart';
import '../../utils/logger.dart';

/// A robust PDF export service that supports Unicode text, Markdown formatting,
/// and code block styling.
class ExportService {
  PdfFont? _bodyFont;
  // ignore: unused_field - Reserved for future Markdown bold rendering
  PdfFont? _boldFont;
  // ignore: unused_field - Reserved for future Markdown italic rendering
  PdfFont? _italicFont;
  PdfFont? _codeFont;
  PdfFont? _headingFont;
  bool _fontsLoaded = false;

  // Page layout constants
  static const double _pageMargin = 40;
  static const double _lineSpacing = 4;
  static const double _paragraphSpacing = 12;
  static const double _codeBlockPadding = 8;

  /// Loads TrueType fonts from assets for Unicode support.
  Future<void> _loadFonts() async {
    if (_fontsLoaded) return;

    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      final fontBytes = fontData.buffer.asUint8List();

      _bodyFont = PdfTrueTypeFont(fontBytes, 11);
      _boldFont = PdfTrueTypeFont(fontBytes, 11); // TODO: Load bold variant
      _italicFont = PdfTrueTypeFont(fontBytes, 11); // TODO: Load italic variant
      _headingFont = PdfTrueTypeFont(fontBytes, 16);
      // Use TrueType for code to support Unicode characters (emojis, etc.)
      _codeFont = PdfTrueTypeFont(fontBytes, 10);
      _fontsLoaded = true;
      Log.i('Loaded TrueType fonts for PDF export');
    } catch (e) {
      Log.w('Failed to load TrueType font, falling back to standard fonts', e);
      _bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
      _boldFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        11,
        style: PdfFontStyle.bold,
      );
      _italicFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        11,
        style: PdfFontStyle.italic,
      );
      _headingFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        16,
        style: PdfFontStyle.bold,
      );
      _codeFont = PdfStandardFont(PdfFontFamily.courier, 10);
      _fontsLoaded = true;
    }
  }

  /// Sanitizes text to remove characters that may not be supported by some fonts.
  /// This strips emoji surrogate pairs and other problematic Unicode characters.
  String _sanitizeText(String text) {
    // Remove emoji and other high Unicode characters that may cause issues
    // Surrogate pairs range: 0xD800-0xDFFF
    // Also removes some control characters
    return text
        .replaceAll(RegExp(r'[\uD800-\uDFFF]'), '')
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '');
  }

  Future<void> exportSessionToPdf(ChatSession session) async {
    await _loadFonts();

    try {
      final document = PdfDocument();
      document.pageSettings.margins.all = _pageMargin;

      PdfPage page = document.pages.add();
      final Size pageSize = page.getClientSize();
      double y = 0;
      int pageNumber = 1;

      // --- Draw Header ---
      y = _drawHeader(page, session, pageSize, y);

      for (final messageMap in session.messages) {
        final isUser = messageMap['isUser'] as bool? ?? false;
        final rawText = messageMap['text'] as String? ?? '';
        final text = _sanitizeText(rawText);

        // Skip empty messages
        if (text.trim().isEmpty) continue;

        // Check if we need a new page before starting a message
        if (y > pageSize.height - 80) {
          _drawFooter(page, pageSize, pageNumber);
          pageNumber++;
          page = document.pages.add();
          y = 0;
        }

        // Draw message and get the updated page and y position
        final result = _drawMessageBlock(
          document: document,
          currentPage: page,
          text: text,
          isUser: isUser,
          startY: y,
          pageSize: pageSize,
          pageNumber: pageNumber,
        );

        // Update references from the tuple
        page = result.$1;
        y = result.$2;
        pageNumber = result.$3;
      }

      // Draw footer on the last page
      _drawFooter(page, pageSize, pageNumber);

      // Save and share
      final List<int> bytes = await document.save();
      document.dispose();

      final directory = await getTemporaryDirectory();
      final fileName = 'chat_export_${session.id.substring(0, 8)}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Chat Export: ${session.title}',
        ),
      );

      Log.i('Exported PDF: ${file.path}');
    } catch (e, stackTrace) {
      Log.e('Failed to export session: $e\n$stackTrace');
      rethrow;
    }
  }

  double _drawHeader(
    PdfPage page,
    ChatSession session,
    Size pageSize,
    double y,
  ) {
    final graphics = page.graphics;

    // Title (sanitize to remove unsupported characters)
    final titleElement = PdfTextElement(
      text: _sanitizeText(session.title),
      font: _headingFont!,
      brush: PdfBrushes.black,
    );
    final titleResult = titleElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageSize.width, 30),
    );
    y = (titleResult?.bounds.bottom ?? y + 30) + _lineSpacing;

    // Date
    final dateStr = DateFormat(
      'MMMM dd, yyyy h:mm a',
    ).format(session.timestamp);
    final dateFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    graphics.drawString(
      'Exported on $dateStr',
      dateFont,
      bounds: Rect.fromLTWH(0, y, pageSize.width, 15),
      brush: PdfBrushes.gray,
    );
    y += 25;

    // Divider
    graphics.drawLine(
      PdfPen(PdfColor(200, 200, 200), width: 0.5),
      Offset(0, y),
      Offset(pageSize.width, y),
    );
    y += 15;

    return y;
  }

  void _drawFooter(PdfPage page, Size pageSize, int pageNumber) {
    final graphics = page.graphics;
    final footerFont = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final footerY = pageSize.height - 10;

    graphics.drawString(
      'Page $pageNumber',
      footerFont,
      bounds: Rect.fromLTWH(0, footerY, pageSize.width, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      brush: PdfBrushes.gray,
    );
  }

  /// Draws a single message block and returns (currentPage, yPosition, pageNumber).
  /// Handles multi-page content by creating new pages as needed.
  (PdfPage, double, int) _drawMessageBlock({
    required PdfDocument document,
    required PdfPage currentPage,
    required String text,
    required bool isUser,
    required double startY,
    required Size pageSize,
    required int pageNumber,
  }) {
    PdfPage page = currentPage;
    double y = startY;
    int currentPageNumber = pageNumber;

    // Sender label
    final senderName = isUser ? 'You' : 'AI';
    final senderFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      9,
      style: PdfFontStyle.bold,
    );
    page.graphics.drawString(
      senderName,
      senderFont,
      bounds: Rect.fromLTWH(0, y, pageSize.width, 12),
      brush: isUser ? PdfBrushes.darkBlue : PdfBrushes.darkGreen,
    );
    y += 14;

    // Parse and render Markdown with pagination support
    final result = _renderMarkdownText(
      document: document,
      currentPage: page,
      text: text,
      startY: y,
      pageSize: pageSize,
      pageNumber: currentPageNumber,
    );

    return (result.$1, result.$2 + _paragraphSpacing, result.$3);
  }

  /// Renders markdown text with pagination support.
  /// Returns (currentPage, yPosition, pageNumber).
  (PdfPage, double, int) _renderMarkdownText({
    required PdfDocument document,
    required PdfPage currentPage,
    required String text,
    required double startY,
    required Size pageSize,
    required int pageNumber,
  }) {
    PdfPage page = currentPage;
    double y = startY;
    int currentPageNumber = pageNumber;

    final lines = text.split('\n');
    bool inCodeBlock = false;
    final codeBlockBuffer = StringBuffer();

    for (final line in lines) {
      // Check for page overflow and add new page if needed
      if (y > pageSize.height - 60) {
        _drawFooter(page, pageSize, currentPageNumber);
        currentPageNumber++;
        page = document.pages.add();
        y = 0;
      }

      // Handle fenced code blocks
      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          // End of code block - render it
          final codeResult = _drawCodeBlock(
            document: document,
            currentPage: page,
            code: codeBlockBuffer.toString(),
            startY: y,
            pageSize: pageSize,
            pageNumber: currentPageNumber,
          );
          page = codeResult.$1;
          y = codeResult.$2;
          currentPageNumber = codeResult.$3;
          codeBlockBuffer.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBlockBuffer.writeln(line);
        continue;
      }

      // Check for headings
      if (line.startsWith('# ')) {
        final textResult = _drawTextLine(
          document: document,
          currentPage: page,
          text: line.substring(2),
          startY: y,
          pageSize: pageSize,
          font: _headingFont!,
          brush: PdfBrushes.black,
          pageNumber: currentPageNumber,
        );
        page = textResult.$1;
        y = textResult.$2 + _lineSpacing * 2;
        currentPageNumber = textResult.$3;
        continue;
      }
      if (line.startsWith('## ')) {
        final headingFont = PdfStandardFont(
          PdfFontFamily.helvetica,
          14,
          style: PdfFontStyle.bold,
        );
        final textResult = _drawTextLine(
          document: document,
          currentPage: page,
          text: line.substring(3),
          startY: y,
          pageSize: pageSize,
          font: headingFont,
          brush: PdfBrushes.black,
          pageNumber: currentPageNumber,
        );
        page = textResult.$1;
        y = textResult.$2 + _lineSpacing;
        currentPageNumber = textResult.$3;
        continue;
      }
      if (line.startsWith('### ')) {
        final headingFont = PdfStandardFont(
          PdfFontFamily.helvetica,
          12,
          style: PdfFontStyle.bold,
        );
        final textResult = _drawTextLine(
          document: document,
          currentPage: page,
          text: line.substring(4),
          startY: y,
          pageSize: pageSize,
          font: headingFont,
          brush: PdfBrushes.black,
          pageNumber: currentPageNumber,
        );
        page = textResult.$1;
        y = textResult.$2 + _lineSpacing;
        currentPageNumber = textResult.$3;
        continue;
      }

      // Check for list items
      if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
        final bulletText = '• ${line.trim().substring(2)}';
        final textResult = _drawTextLine(
          document: document,
          currentPage: page,
          text: bulletText,
          startY: y,
          pageSize: pageSize,
          font: _bodyFont!,
          brush: PdfBrushes.black,
          pageNumber: currentPageNumber,
        );
        page = textResult.$1;
        y = textResult.$2;
        currentPageNumber = textResult.$3;
        continue;
      }

      // Check for numbered lists
      final numberedMatch = RegExp(r'^\d+\.\s').firstMatch(line.trim());
      if (numberedMatch != null) {
        final textResult = _drawTextLine(
          document: document,
          currentPage: page,
          text: line.trim(),
          startY: y,
          pageSize: pageSize,
          font: _bodyFont!,
          brush: PdfBrushes.black,
          pageNumber: currentPageNumber,
        );
        page = textResult.$1;
        y = textResult.$2;
        currentPageNumber = textResult.$3;
        continue;
      }

      // Regular paragraph
      if (line.trim().isEmpty) {
        y += _paragraphSpacing / 2;
      } else {
        final textResult = _drawTextLine(
          document: document,
          currentPage: page,
          text: line,
          startY: y,
          pageSize: pageSize,
          font: _bodyFont!,
          brush: PdfBrushes.black,
          pageNumber: currentPageNumber,
        );
        page = textResult.$1;
        y = textResult.$2;
        currentPageNumber = textResult.$3;
      }
    }

    // Handle unclosed code block
    if (inCodeBlock && codeBlockBuffer.isNotEmpty) {
      final codeResult = _drawCodeBlock(
        document: document,
        currentPage: page,
        code: codeBlockBuffer.toString(),
        startY: y,
        pageSize: pageSize,
        pageNumber: currentPageNumber,
      );
      page = codeResult.$1;
      y = codeResult.$2;
      currentPageNumber = codeResult.$3;
    }

    return (page, y, currentPageNumber);
  }

  /// Draws a single text line with pagination support.
  /// Returns (currentPage, yPosition, pageNumber).
  (PdfPage, double, int) _drawTextLine({
    required PdfDocument document,
    required PdfPage currentPage,
    required String text,
    required double startY,
    required Size pageSize,
    required PdfFont font,
    required PdfBrush brush,
    required int pageNumber,
  }) {
    PdfPage page = currentPage;
    double y = startY;
    int currentPageNumber = pageNumber;

    // Check for page overflow before drawing
    if (y > pageSize.height - 40) {
      _drawFooter(page, pageSize, currentPageNumber);
      currentPageNumber++;
      page = document.pages.add();
      y = 0;
    }

    final element = PdfTextElement(text: text, font: font, brush: brush);
    final result = element.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageSize.width, 0),
    );

    // Handle case where text spans to a new page
    if (result?.page != null && result!.page != page) {
      page = result.page;
      // Note: The result.bounds should already reflect the new page position
    }

    final newY = (result?.bounds.bottom ?? y + 14) + _lineSpacing;
    return (page, newY, currentPageNumber);
  }

  /// Draws a code block with pagination support.
  /// Returns (currentPage, yPosition, pageNumber).
  (PdfPage, double, int) _drawCodeBlock({
    required PdfDocument document,
    required PdfPage currentPage,
    required String code,
    required double startY,
    required Size pageSize,
    required int pageNumber,
  }) {
    PdfPage page = currentPage;
    double y = startY;
    int currentPageNumber = pageNumber;

    // Measure code block height
    final codeSize = _codeFont!.measureString(
      code,
      layoutArea: Size(pageSize.width - _codeBlockPadding * 2, 0),
    );

    final blockHeight = codeSize.height + _codeBlockPadding * 2;

    // Check if we need a new page for this code block
    if (y + blockHeight > pageSize.height - 40) {
      _drawFooter(page, pageSize, currentPageNumber);
      currentPageNumber++;
      page = document.pages.add();
      y = 0;
    }

    final graphics = page.graphics;

    final blockRect = Rect.fromLTWH(0, y, pageSize.width, blockHeight);

    // Draw background
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(245, 245, 245)),
      bounds: blockRect,
    );

    // Draw border
    graphics.drawRectangle(
      pen: PdfPen(PdfColor(220, 220, 220), width: 0.5),
      bounds: blockRect,
    );

    // Draw code text
    final codeElement = PdfTextElement(
      text: code.trim(),
      font: _codeFont!,
      brush: PdfBrushes.black,
    );
    codeElement.draw(
      page: page,
      bounds: Rect.fromLTWH(
        _codeBlockPadding,
        y + _codeBlockPadding,
        pageSize.width - _codeBlockPadding * 2,
        codeSize.height,
      ),
    );

    return (page, y + blockHeight + _paragraphSpacing, currentPageNumber);
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});
