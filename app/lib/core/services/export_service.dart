import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../storage/models/chat_session.dart';
import '../utils/logger.dart';

class ExportService {
  Future<void> exportSessionToPdf(ChatSession session) async {
    try {
      final document = PdfDocument();
      final page = document.pages.add();
      final Size pageSize = page.getClientSize();

      // Draw Title
      final PdfFont titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        18,
        style: PdfFontStyle.bold,
      );
      final PdfFont dateFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
      final PdfFont contentFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

      double y = 0;

      // Title
      page.graphics.drawString(
        session.title,
        titleFont,
        bounds: Rect.fromLTWH(0, y, pageSize.width, 30),
      );
      y += 30;

      // Date
      final dateStr = DateFormat(
        'MMM dd, yyyy h:mm a',
      ).format(session.timestamp);
      page.graphics.drawString(
        'Exported on $dateStr',
        dateFont,
        bounds: Rect.fromLTWH(0, y, pageSize.width, 20),
        brush: PdfBrushes.gray,
      );
      y += 40;

      // Draw Divider
      page.graphics.drawLine(
        PdfPen(PdfColor(200, 200, 200)),
        Offset(0, y),
        Offset(pageSize.width, y),
      );
      y += 20;

      // Draw Messages
      for (final messageMap in session.messages) {
        final isUser = messageMap['isUser'] as bool? ?? false;
        final text = messageMap['text'] as String? ?? '';
        final timestampStr = messageMap['timestamp'] as String?;
        DateTime? timestamp;
        if (timestampStr != null) {
          timestamp = DateTime.tryParse(timestampStr);
        }

        // Check if we need a new page
        if (y > pageSize.height - 100) {
          document.pages.add();
          y = 20;
        }

        // Draw Message Bubble
        final PdfLayoutResult? result = _drawMessage(
          page: document.pages[document.pages.count - 1],
          text: text,
          isUser: isUser,
          y: y,
          font: contentFont,
          timestamp: timestamp,
          pageSize: pageSize,
        );

        if (result != null) {
          y = result.bounds.bottom + 20;
        }
      }

      // Save to file
      final List<int> bytes = await document.save();
      document.dispose();

      final directory = await getTemporaryDirectory();
      final fileName = 'chat_export_${session.id.substring(0, 8)}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Share
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

  PdfLayoutResult? _drawMessage({
    required PdfPage page,
    required String text,
    required bool isUser,
    required double y,
    required PdfFont font,
    DateTime? timestamp,
    required Size pageSize,
  }) {
    final PdfGraphics graphics = page.graphics;
    const double bubblePadding = 10;
    const double maxWidth = 400;

    // Measure text size
    final Size textSize = font.measureString(
      text,
      layoutArea: const Size(maxWidth, 0),
    );

    double x = isUser
        ? pageSize.width - textSize.width - (bubblePadding * 2)
        : 0;

    // Draw Sender Name
    final senderName = isUser ? 'You' : 'AI';
    final PdfFont senderFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      8,
      style: PdfFontStyle.bold,
    );
    graphics.drawString(
      senderName,
      senderFont,
      bounds: Rect.fromLTWH(x, y, maxWidth, 15),
      brush: PdfBrushes.gray,
    );
    y += 15;

    // Draw Bubble Background
    final Rect bubbleRect = Rect.fromLTWH(
      x,
      y,
      textSize.width + (bubblePadding * 2),
      textSize.height + (bubblePadding * 2),
    );

    final PdfBrush bubbleBrush = isUser
        ? PdfSolidBrush(PdfColor(230, 230, 230)) // Light gray for user
        : PdfSolidBrush(PdfColor(245, 245, 245)); // Lighter gray for AI

    graphics.drawRectangle(brush: bubbleBrush, bounds: bubbleRect);

    // Draw Text
    final PdfTextElement textElement = PdfTextElement(text: text, font: font);
    textElement.brush = PdfBrushes.black;

    final PdfLayoutResult? result = textElement.draw(
      page: page,
      bounds: Rect.fromLTWH(
        x + bubblePadding,
        y + bubblePadding,
        maxWidth,
        textSize.height + 100, // Allow height expansion
      ),
    );

    return result;
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});
