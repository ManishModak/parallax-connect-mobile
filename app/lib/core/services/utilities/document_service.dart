import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../features/settings/data/settings_storage.dart';

class DocumentService {
  final SettingsStorage _settingsStorage;

  DocumentService(this._settingsStorage);

  /// Supported text file extensions
  static const _textExtensions = ['.txt', '.md', '.json', '.xml', '.csv'];

  Future<String> extractText(String filePath) async {
    final file = File(filePath);
    final ext = filePath.toLowerCase().split('.').last;

    String text;
    if (ext == 'pdf') {
      text = await _extractPdfText(file);
    } else if (_textExtensions.any((e) => filePath.toLowerCase().endsWith(e))) {
      text = await _extractPlainText(file);
    } else {
      // Attempt PDF extraction as fallback for unknown types
      text = await _extractPdfText(file);
    }

    return _processContext(text);
  }

  Future<String> _extractPdfText(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();
    return text;
  }

  Future<String> _extractPlainText(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      // Fallback for non-UTF-8 files
      final bytes = await file.readAsBytes();
      return String.fromCharCodes(bytes);
    }
  }

  String _processContext(String text) {
    final maxTokens = _settingsStorage.getMaxContextTokens();
    final smartContext = _settingsStorage.getSmartContextEnabled();

    // Rough estimate: 1 token ≈ 4 characters
    final maxChars = maxTokens * 4;

    if (text.length <= maxChars) return text;

    if (smartContext) {
      // RAG-style chunking: return most relevant chunk
      return _smartChunk(text, maxChars);
    } else {
      // Simple truncation
      return '${text.substring(0, maxChars)}...\n\n[Truncated: ${text.length} chars total]';
    }
  }

  String _smartChunk(String text, int maxChars) {
    // Split into paragraphs, take first chunks up to limit
    final paragraphs = text.split(RegExp(r'\n\n+'));
    final buffer = StringBuffer();

    for (final para in paragraphs) {
      if (buffer.length + para.length > maxChars) break;
      buffer.writeln(para);
      buffer.writeln();
    }

    return buffer.toString().trim();
  }
}

final documentServiceProvider = Provider<DocumentService>((ref) {
  final settingsStorage = ref.watch(settingsStorageProvider);
  return DocumentService(settingsStorage);
});
