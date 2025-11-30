import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../features/chat/data/chat_repository.dart';
import '../../features/settings/data/settings_storage.dart';
import '../utils/logger.dart';

/// Service for processing images using either on-device ML Kit or server-side vision
class VisionService {
  final SettingsStorage _settingsStorage;
  final ChatRepository _chatRepository;

  VisionService(this._settingsStorage, this._chatRepository);

  /// Analyze an image using the configured pipeline mode
  /// - 'edge': On-device processing via Google ML Kit (OCR + Labels + Objects)
  /// - 'multimodal': Server-side processing
  Future<String> analyzeImage(String imagePath, String prompt) async {
    final mode = _settingsStorage.getVisionPipelineMode();
    Log.i('Vision mode: $mode');

    if (mode == 'edge') {
      return _analyzeWithMLKit(imagePath, prompt);
    } else {
      return _analyzeWithServer(imagePath, prompt);
    }
  }

  /// On-device image analysis using multiple ML Kit APIs
  Future<String> _analyzeWithMLKit(String imagePath, String prompt) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final response = StringBuffer()..writeln('**Image Analysis (On-Device)**');

    // Run all analyzers in parallel
    final results = await Future.wait([
      _extractText(inputImage),
      _detectLabels(inputImage),
      _detectObjects(inputImage),
    ]);

    final textResult = results[0];
    final labelsResult = results[1];
    final objectsResult = results[2];

    bool hasContent = false;

    // Text Recognition (OCR) - most useful for documents/screenshots
    if (textResult != null && textResult.isNotEmpty) {
      hasContent = true;
      response
        ..writeln()
        ..writeln('**Text Found:**')
        ..writeln('```')
        ..writeln(textResult)
        ..writeln('```');
    }

    // Object Detection - specific objects with locations
    if (objectsResult != null && objectsResult.isNotEmpty) {
      hasContent = true;
      response
        ..writeln()
        ..writeln('**Objects Detected:**')
        ..writeln(objectsResult);
    }

    // Image Labels - general scene/content understanding
    if (labelsResult != null && labelsResult.isNotEmpty) {
      hasContent = true;
      response
        ..writeln()
        ..writeln('**Scene Labels:**')
        ..writeln(labelsResult);
    }

    if (!hasContent) {
      response
        ..writeln()
        ..writeln('No significant content detected in this image.');
    }

    // Add note about limitations if user asked a specific question
    if (prompt.isNotEmpty && prompt != 'Describe this image') {
      response
        ..writeln()
        ..writeln('---')
        ..writeln(
          '_On-device analysis provides detection only. '
          'For detailed understanding or answering questions about the image, '
          'switch to multimodal mode._',
        );
    }

    return response.toString();
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
            (l) =>
                '• ${l.label} (${(l.confidence * 100).toStringAsFixed(0)}%)',
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
  Future<String> _analyzeWithServer(String imagePath, String prompt) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      Log.network('Sending image (${bytes.length} bytes)');
      return _chatRepository.analyzeImage(prompt, base64Image);
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
