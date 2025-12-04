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
      _codeFont = PdfStandardFont(PdfFontFamily.courier, 10);
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

      // --- Draw Messages ---
      for (final messageMap in session.messages) {
        final isUser = messageMap['isUser'] as bool? ?? false;
        final text = messageMap['text'] as String? ?? '';

        // Check if we need a new page
        if (y > pageSize.height - 80) {
          _drawFooter(page, pageSize, pageNumber);
          pageNumber++;
          page = document.pages.add();
          y = 0;
        }

        y = _drawMessageBlock(
          document: document,
          page: page,
          text: text,
          isUser: isUser,
          y: y,
          pageSize: pageSize,
          pageNumber: pageNumber,
        );
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
    } catch (e) {
      Log.e('Failed to export session', e);
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

    // Title
    final titleElement = PdfTextElement(
      text: session.title,
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

  double _drawMessageBlock({
    required PdfDocument document,
    required PdfPage page,
    required String text,
    required bool isUser,
    required double y,
    required Size pageSize,
    required int pageNumber,
  }) {
    final graphics = page.graphics;

    // Sender label
    final senderName = isUser ? 'You' : 'AI';
    final senderFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      9,
      style: PdfFontStyle.bold,
    );
    graphics.drawString(
      senderName,
      senderFont,
      bounds: Rect.fromLTWH(0, y, pageSize.width, 12),
      brush: isUser ? PdfBrushes.darkBlue : PdfBrushes.darkGreen,
    );
    y += 14;

    // Parse and render Markdown
    y = _renderMarkdownText(page, text, y, pageSize);

    return y + _paragraphSpacing;
  }

  double _renderMarkdownText(
    PdfPage page,
    String text,
    double y,
    Size pageSize,
  ) {
    final lines = text.split('\n');
    bool inCodeBlock = false;
    final codeBlockBuffer = StringBuffer();

    for (final line in lines) {
      // Handle fenced code blocks
      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          // End of code block - render it
          y = _drawCodeBlock(page, codeBlockBuffer.toString(), y, pageSize);
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
        y = _drawTextLine(
          page,
          line.substring(2),
          y,
          pageSize,
          _headingFont!,
          PdfBrushes.black,
        );
        y += _lineSpacing * 2;
        continue;
      }
      if (line.startsWith('## ')) {
        final headingFont = PdfStandardFont(
          PdfFontFamily.helvetica,
          14,
          style: PdfFontStyle.bold,
        );
        y = _drawTextLine(
          page,
          line.substring(3),
          y,
          pageSize,
          headingFont,
          PdfBrushes.black,
        );
        y += _lineSpacing;
        continue;
      }
      if (line.startsWith('### ')) {
        final headingFont = PdfStandardFont(
          PdfFontFamily.helvetica,
          12,
          style: PdfFontStyle.bold,
        );
        y = _drawTextLine(
          page,
          line.substring(4),
          y,
          pageSize,
          headingFont,
          PdfBrushes.black,
        );
        y += _lineSpacing;
        continue;
      }

      // Check for list items
      if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
        final bulletText = '• ${line.trim().substring(2)}';
        y = _drawTextLine(
          page,
          bulletText,
          y,
          pageSize,
          _bodyFont!,
          PdfBrushes.black,
        );
        continue;
      }

      // Check for numbered lists
      final numberedMatch = RegExp(r'^\d+\.\s').firstMatch(line.trim());
      if (numberedMatch != null) {
        y = _drawTextLine(
          page,
          line.trim(),
          y,
          pageSize,
          _bodyFont!,
          PdfBrushes.black,
        );
        continue;
      }

      // Regular paragraph
      if (line.trim().isEmpty) {
        y += _paragraphSpacing / 2;
      } else {
        y = _drawTextLine(
          page,
          line,
          y,
          pageSize,
          _bodyFont!,
          PdfBrushes.black,
        );
      }
    }

    // Handle unclosed code block
    if (inCodeBlock && codeBlockBuffer.isNotEmpty) {
      y = _drawCodeBlock(page, codeBlockBuffer.toString(), y, pageSize);
    }

    return y;
  }

  double _drawTextLine(
    PdfPage page,
    String text,
    double y,
    Size pageSize,
    PdfFont font,
    PdfBrush brush,
  ) {
    final element = PdfTextElement(text: text, font: font, brush: brush);
    final result = element.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageSize.width, 0),
    );
    return (result?.bounds.bottom ?? y + 14) + _lineSpacing;
  }

  double _drawCodeBlock(PdfPage page, String code, double y, Size pageSize) {
    final graphics = page.graphics;

    // Measure code block height
    final codeSize = _codeFont!.measureString(
      code,
      layoutArea: Size(pageSize.width - _codeBlockPadding * 2, 0),
    );

    final blockRect = Rect.fromLTWH(
      0,
      y,
      pageSize.width,
      codeSize.height + _codeBlockPadding * 2,
    );

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

    return y + blockRect.height + _paragraphSpacing;
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});
