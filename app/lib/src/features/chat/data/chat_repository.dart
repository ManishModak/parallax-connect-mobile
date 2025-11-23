import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/networking/dio_provider.dart';
import '../../../core/storage/config_storage.dart';
import '../../../core/utils/logger.dart';

class ChatRepository {
  final Dio _dio;
  final ConfigStorage _configStorage;

  ChatRepository(this._dio, this._configStorage);

  Future<String> generateText(String prompt) async {
    final baseUrl = _configStorage.getBaseUrl();
    if (baseUrl == null) throw Exception('No Base URL configured');

    try {
      final response = await _dio.post(
        '$baseUrl/generate',
        data: {'prompt': prompt},
      );

      return response.data['response'] as String;
    } catch (e) {
      logger.e('Error generating text', error: e);
      rethrow;
    }
  }

  Future<String> analyzeImage(String prompt, String imageBase64) async {
    final baseUrl = _configStorage.getBaseUrl();
    if (baseUrl == null) throw Exception('No Base URL configured');

    try {
      final response = await _dio.post(
        '$baseUrl/analyze',
        data: {'prompt': prompt, 'image': imageBase64},
      );

      return response.data['response'] as String;
    } catch (e) {
      logger.e('Error analyzing image', error: e);
      rethrow;
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final configStorage = ref.watch(configStorageProvider);
  return ChatRepository(dio, configStorage);
});
