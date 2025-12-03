import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/network/dio_provider.dart';
import '../../../../core/services/storage/config_storage.dart';
import '../../../../core/utils/logger.dart';
import '../../models/chat_message.dart';

/// Represents a streaming event from the server
class StreamEvent {
  final String type; // 'thinking', 'content', 'done', 'error'
  final String? content;
  final Map<String, dynamic>? metadata;
  final String? errorMessage;

  StreamEvent({
    required this.type,
    this.content,
    this.metadata,
    this.errorMessage,
  });

  factory StreamEvent.fromJson(Map<String, dynamic> json) {
    // Safely cast metadata - it might be deeply nested JSON
    Map<String, dynamic>? metadata;
    if (json['metadata'] != null) {
      if (json['metadata'] is Map<String, dynamic>) {
        metadata = json['metadata'] as Map<String, dynamic>;
      } else if (json['metadata'] is Map) {
        metadata = Map<String, dynamic>.from(json['metadata'] as Map);
      }
    }

    return StreamEvent(
      type: json['type'] as String,
      content: json['content'] as String?,
      metadata: metadata,
      errorMessage: json['message'] as String?,
    );
  }

  bool get isThinking => type == 'thinking';
  bool get isContent => type == 'content';
  bool get isDone => type == 'done';
  bool get isError => type == 'error';
  bool get isSearchResults => type == 'search_results';
}

class ChatRepository {
  final Dio _dio;
  final ConfigStorage _configStorage;

  ChatRepository(this._dio, this._configStorage);

  Map<String, String>? _buildPasswordHeader() {
    final password = _configStorage.getPassword();
    if (password == null || password.isEmpty) {
      return null;
    }
    return {'x-password': password};
  }

  /// Test connection to the server
  Future<bool> testConnection() async {
    final baseUrl = _configStorage.getBaseUrl();
    if (baseUrl == null) return false;

    try {
      final response = await _dio.get(
        '$baseUrl/',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
          headers: _buildPasswordHeader(),
        ),
      );

      return response.statusCode == 200 && response.data['status'] == 'online';
    } catch (e) {
      logger.e('Connection test failed', error: e);
      return false;
    }
  }

  /// Generate text response from AI
  ///
  /// [prompt] - The current user message
  /// [systemPrompt] - Optional system instructions
  /// [history] - Optional conversation history for multi-turn chat
  ///
  /// Note: Parallax uses the model set during scheduler initialization,
  /// not a per-request model parameter. Model selection is done via the
  /// Parallax Web UI, not through the API.
  Future<String> generateText(
    String prompt, {
    String? systemPrompt,
    List<ChatMessage>? history,
  }) async {
    final baseUrl = _configStorage.getBaseUrl();
    if (baseUrl == null) throw Exception('No Base URL configured');

    try {
      final data = <String, dynamic>{'prompt': prompt};

      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        data['system_prompt'] = systemPrompt;
      }

      // Include conversation history for multi-turn chat
      if (history != null && history.isNotEmpty) {
        data['messages'] = [
          ...history.map(
            (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
          ),
          // Add current prompt as the last user message
          {'role': 'user', 'content': prompt},
        ];
      }

      final response = await _dio.post(
        '$baseUrl/chat',
        data: data,
        options: Options(headers: _buildPasswordHeader()),
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
        '$baseUrl/vision',
        data: {'prompt': prompt, 'image': imageBase64},
        options: Options(headers: _buildPasswordHeader()),
      );

      return response.data['response'] as String;
    } catch (e) {
      logger.e('Error analyzing image', error: e);
      rethrow;
    }
  }

  /// Generate streaming text response from AI
  ///
  /// Returns a Stream of [StreamEvent] objects containing:
  /// - thinking: Model's reasoning process (from `<think>` tags)
  /// - content: Final response content
  /// - done: Stream complete with metadata
  /// - error: Error occurred
  Stream<StreamEvent> generateTextStream(
    String prompt, {
    String? systemPrompt,
    List<ChatMessage>? history,
    bool webSearchEnabled = false,
    String webSearchDepth = 'normal',
  }) async* {
    final baseUrl = _configStorage.getBaseUrl();
    if (baseUrl == null) {
      yield StreamEvent(type: 'error', errorMessage: 'No Base URL configured');
      return;
    }

    try {
      final data = <String, dynamic>{
        'prompt': prompt,
        'web_search_enabled': webSearchEnabled,
        'web_search_depth': webSearchDepth,
      };

      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        data['system_prompt'] = systemPrompt;
      }

      // Include conversation history for multi-turn chat
      if (history != null && history.isNotEmpty) {
        data['messages'] = [
          ...history.map(
            (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
          ),
          {'role': 'user', 'content': prompt},
        ];
      }

      final uri = Uri.parse('$baseUrl/chat/stream');
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';

      final password = _configStorage.getPassword();
      if (password != null && password.isNotEmpty) {
        request.headers['x-password'] = password;
      }

      request.body = jsonEncode(data);

      final client = http.Client();
      try {
        final response = await client.send(request);

        if (response.statusCode != 200) {
          final body = await response.stream.bytesToString();
          yield StreamEvent(type: 'error', errorMessage: 'Server error: $body');
          return;
        }

        // Parse SSE stream
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6).trim();
              if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

              try {
                final json = jsonDecode(jsonStr) as Map<String, dynamic>;
                yield StreamEvent.fromJson(json);
              } catch (e) {
                logger.w('Failed to parse SSE event: $jsonStr');
              }
            }
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      logger.e('Error in streaming', error: e);
      yield StreamEvent(
        type: 'error',
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final configStorage = ref.watch(configStorageProvider);
  return ChatRepository(dio, configStorage);
});
