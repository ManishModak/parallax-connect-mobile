import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../features/chat/data/repositories/chat_repository.dart';
import '../../../features/settings/data/settings_storage.dart';
import '../../utils/logger.dart';

/// Service for processing images using either on-device ML Kit or server-side vision
class VisionService {
  final SettingsStorage _settingsStorage;
  final ChatRepository _chatRepository;

  VisionService(this._settingsStorage, this._chatRepository);

  /// Analyze an image using the configured pipeline mode
  /// - 'auto': Use server if available, else edge (default recommended)
  /// - 'edge': On-device processing via Google ML Kit (OCR + Labels + Objects)
  /// - 'server': Server-side OCR via middleware /vision endpoint
  /// - 'multimodal': Server-side processing (not yet implemented in Parallax)
  ///
  /// [systemPrompt] is the user's custom system prompt from settings.
  /// For server modes, it's sent along with the image.
  /// For edge mode, the OCR result is returned directly (no LLM call).
  ///
  /// Note: 'server' mode automatically falls back to 'edge' on failure.
  Future<String> analyzeImage(
    String imagePath,
    String prompt, {
    bool serverAvailable = false,
    String? systemPrompt,
  }) async {
    var mode = _settingsStorage.getVisionPipelineMode();
    Log.i('Vision mode setting: $mode, serverAvailable: $serverAvailable');

    // Auto-select: prefer server if available
    if (mode == 'auto') {
      mode = serverAvailable ? 'server' : 'edge';
      Log.i('Auto-selected vision mode: $mode');
    }

    // If user selected 'server' but it's not available, use edge
    if (mode == 'server' && !serverAvailable) {
      Log.w('Server OCR unavailable, falling back to Edge OCR');
      mode = 'edge';
    }

    switch (mode) {
      case 'edge':
        // Edge mode: Local extraction → Send context to LLM for understanding
        return _analyzeWithMLKit(imagePath, prompt, systemPrompt: systemPrompt);
      case 'server':
        return _analyzeWithServerOCR(imagePath, prompt, systemPrompt);
      case 'multimodal':
      default:
        return _analyzeWithServer(imagePath, prompt, systemPrompt);
    }
  }

  /// Server-side OCR via middleware /vision endpoint
  /// Falls back to Edge OCR on any error
  Future<String> _analyzeWithServerOCR(
    String imagePath,
    String prompt,
    String? systemPrompt,
  ) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      Log.network('Sending image to server OCR (${bytes.length} bytes)');

      final response = await _chatRepository.analyzeImage(
        prompt.isEmpty ? 'Describe this image' : prompt,
        base64Image,
        systemPrompt: systemPrompt,
      );
      return response;
    } catch (e) {
      Log.e('Server OCR failed, falling back to Edge OCR', e);
      return _analyzeWithMLKit(imagePath, prompt, systemPrompt: systemPrompt);
    }
  }

  /// On-device image analysis using ML Kit, then send context to LLM
  /// This extracts text/labels locally for privacy, then uses /chat for understanding
  Future<String> _analyzeWithMLKit(
    String imagePath,
    String prompt, {
    String? systemPrompt,
  }) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    // Run all analyzers in parallel
    final results = await Future.wait([
      _extractText(inputImage),
      _detectLabels(inputImage),
      _detectObjects(inputImage),
    ]);

    final textResult = results[0];
    final labelsResult = results[1];
    final objectsResult = results[2];

    // Build context from local analysis
    final contextParts = <String>[];

    if (textResult != null && textResult.isNotEmpty) {
      contextParts.add('Text found in image:\n$textResult');
    }

    if (objectsResult != null && objectsResult.isNotEmpty) {
      contextParts.add('Objects detected:\n$objectsResult');
    }

    if (labelsResult != null && labelsResult.isNotEmpty) {
      contextParts.add('Scene labels:\n$labelsResult');
    }

    // If no content detected, return early
    if (contextParts.isEmpty) {
      return 'No significant content detected in this image.';
    }

    // Send extracted context to LLM via /chat for natural understanding
    final context = contextParts.join('\n\n');
    final userPrompt = prompt.isEmpty ? 'Describe this image' : prompt;

    try {
      Log.i('Edge OCR: Sending extracted context to LLM');
      final response = await _chatRepository.generateText(
        'Based on the following image analysis:\n\n$context\n\nUser request: $userPrompt',
        systemPrompt: systemPrompt,
      );
      return response;
    } catch (e) {
      // Fallback: return raw analysis if LLM call fails
      Log.w('Edge OCR: LLM call failed, returning raw analysis', e);
      final response = StringBuffer()
        ..writeln('**Image Analysis (On-Device)**');

      if (textResult != null && textResult.isNotEmpty) {
        response
          ..writeln()
          ..writeln('**Text Found:**')
          ..writeln('```')
          ..writeln(textResult)
          ..writeln('```');
      }

      if (objectsResult != null && objectsResult.isNotEmpty) {
        response
          ..writeln()
          ..writeln('**Objects Detected:**')
          ..writeln(objectsResult);
      }

      if (labelsResult != null && labelsResult.isNotEmpty) {
        response
          ..writeln()
          ..writeln('**Scene Labels:**')
          ..writeln(labelsResult);
      }

      return response.toString();
    }
  }

  /// Extract text using OCR
  Future<String?> _extractText(InputImage inputImage) async {
    final textRecognizer = TextRecognizer();
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      if (recognizedText.text.trim().isEmpty) return null;
      Log.d('OCR: ${recognizedText.text.length} chars');
      return recognizedText.text.trim();
    } catch (e) {
      Log.e('Text recognition failed', e);
      return null;
    } finally {
      textRecognizer.close();
    }
  }

  /// Detect image labels (scene classification)
  Future<String?> _detectLabels(InputImage inputImage) async {
    final labeler = ImageLabeler(options: ImageLabelerOptions());
    try {
      final labels = await labeler.processImage(inputImage);
      final filtered = labels.where((l) => l.confidence > 0.6).toList();
      if (filtered.isEmpty) return null;

      Log.d('Labels: ${filtered.length}');
      return filtered
          .map(
            (l) => '• ${l.label} (${(l.confidence * 100).toStringAsFixed(0)}%)',
          )
          .join('\n');
    } catch (e) {
      Log.e('Image labeling failed', e);
      return null;
    } finally {
      labeler.close();
    }
  }

  /// Detect objects with bounding info
  Future<String?> _detectObjects(InputImage inputImage) async {
    final objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
    try {
      final objects = await objectDetector.processImage(inputImage);
      if (objects.isEmpty) return null;

      Log.d('Objects: ${objects.length}');
      final descriptions = <String>[];

      for (final obj in objects) {
        if (obj.labels.isNotEmpty) {
          final label = obj.labels.first;
          descriptions.add(
            '• ${label.text} (${(label.confidence * 100).toStringAsFixed(0)}%)',
          );
        }
      }

      return descriptions.isEmpty ? null : descriptions.join('\n');
    } catch (e) {
      Log.e('Object detection failed', e);
      return null;
    } finally {
      objectDetector.close();
    }
  }

  /// Server-side image analysis
  Future<String> _analyzeWithServer(
    String imagePath,
    String prompt,
    String? systemPrompt,
  ) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      Log.network('Sending image (${bytes.length} bytes)');
      return _chatRepository.analyzeImage(
        prompt,
        base64Image,
        systemPrompt: systemPrompt,
      );
    } catch (e) {
      Log.e('Server image analysis failed', e);
      rethrow;
    }
  }
}

final visionServiceProvider = Provider<VisionService>((ref) {
  final settingsStorage = ref.watch(settingsStorageProvider);
  final chatRepository = ref.watch(chatRepositoryProvider);
  return VisionService(settingsStorage, chatRepository);
});
