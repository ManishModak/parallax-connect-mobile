import 'package:flutter_test/flutter_test.dart';
import 'package:parallax_connect/features/chat/presentation/state/chat_state.dart';
import 'package:parallax_connect/features/chat/models/chat_message.dart';

void main() {
  group('ChatState', () {
    test('should have correct default values', () {
      const state = ChatState();

      expect(state.messages, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.isPrivateMode, isFalse);
      expect(state.currentSessionId, isNull);
      expect(state.isStreaming, isFalse);
      expect(state.streamingContent, isEmpty);
      expect(state.thinkingContent, isEmpty);
      expect(state.isThinking, isFalse);
      expect(state.isAnalyzingIntent, isFalse);
      expect(state.isSearchingWeb, isFalse);
      expect(state.searchStatusMessage, isEmpty);
      expect(state.webSearchMode, 'deep');
      expect(state.editingMessage, isNull);
      expect(state.lastSearchMetadata, isNull);
    });

    test('copyWith should preserve unchanged values', () {
      final message = ChatMessage(
        text: 'Test',
        isUser: true,
        timestamp: DateTime.now(),
      );

      final state = ChatState(
        messages: [message],
        isLoading: true,
        isPrivateMode: true,
        webSearchMode: 'off',
      );

      final newState = state.copyWith(isStreaming: true);

      expect(newState.messages, [message]);
      expect(newState.isLoading, isTrue);
      expect(newState.isPrivateMode, isTrue);
      expect(newState.webSearchMode, 'off');
      expect(newState.isStreaming, isTrue);
    });

    test('copyWith clearError should set error to null', () {
      final state = ChatState(error: 'Some error');

      final newState = state.copyWith(clearError: true);

      expect(newState.error, isNull);
    });

    test('copyWith clearEditingMessage should set editingMessage to null', () {
      final message = ChatMessage(
        text: 'Test',
        isUser: true,
        timestamp: DateTime.now(),
      );

      final state = ChatState(editingMessage: message);

      final newState = state.copyWith(clearEditingMessage: true);

      expect(newState.editingMessage, isNull);
    });

    test(
      'copyWith clearLastSearchMetadata should set lastSearchMetadata to null',
      () {
        final state = ChatState(lastSearchMetadata: {'query': 'test'});

        final newState = state.copyWith(clearLastSearchMetadata: true);

        expect(newState.lastSearchMetadata, isNull);
      },
    );

    test('copyWith should override values when provided', () {
      const state = ChatState();

      final newState = state.copyWith(
        isLoading: true,
        isStreaming: true,
        streamingContent: 'Hello',
        thinkingContent: 'Thinking...',
        isThinking: true,
        isAnalyzingIntent: true,
        isSearchingWeb: true,
        searchStatusMessage: 'Searching...',
        webSearchMode: 'normal',
      );

      expect(newState.isLoading, isTrue);
      expect(newState.isStreaming, isTrue);
      expect(newState.streamingContent, 'Hello');
      expect(newState.thinkingContent, 'Thinking...');
      expect(newState.isThinking, isTrue);
      expect(newState.isAnalyzingIntent, isTrue);
      expect(newState.isSearchingWeb, isTrue);
      expect(newState.searchStatusMessage, 'Searching...');
      expect(newState.webSearchMode, 'normal');
    });
  });
}
