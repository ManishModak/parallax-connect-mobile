import 'package:flutter_test/flutter_test.dart';
import 'package:parallax_connect/features/chat/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('should create with required fields', () {
      final now = DateTime.now();
      final message = ChatMessage(text: 'Hello', isUser: true, timestamp: now);

      expect(message.text, 'Hello');
      expect(message.isUser, isTrue);
      expect(message.timestamp, now);
      expect(message.attachmentPaths, isEmpty);
      expect(message.thinkingContent, isNull);
      expect(message.searchMetadata, isNull);
    });

    test('should create with optional fields', () {
      final now = DateTime.now();
      final message = ChatMessage(
        text: 'Hello',
        isUser: false,
        timestamp: now,
        attachmentPaths: ['/path/to/file.png'],
        thinkingContent: 'Let me think...',
        searchMetadata: {'query': 'test', 'results': []},
      );

      expect(message.attachmentPaths, ['/path/to/file.png']);
      expect(message.thinkingContent, 'Let me think...');
      expect(message.searchMetadata, {'query': 'test', 'results': []});
    });

    group('toMap', () {
      test('should serialize all fields', () {
        final now = DateTime(2024, 1, 15, 10, 30, 0);
        final message = ChatMessage(
          text: 'Test message',
          isUser: true,
          timestamp: now,
          attachmentPaths: ['/path/to/image.jpg'],
          thinkingContent: 'Thinking...',
          searchMetadata: {'query': 'search'},
        );

        final map = message.toMap();

        expect(map['text'], 'Test message');
        expect(map['isUser'], isTrue);
        expect(map['timestamp'], now.toIso8601String());
        expect(map['attachmentPaths'], ['/path/to/image.jpg']);
        expect(map['thinkingContent'], 'Thinking...');
        expect(map['searchMetadata'], {'query': 'search'});
      });
    });

    group('fromMap', () {
      test('should deserialize all fields', () {
        final map = {
          'text': 'Restored message',
          'isUser': false,
          'timestamp': '2024-01-15T10:30:00.000',
          'attachmentPaths': ['/path/to/file.pdf'],
          'thinkingContent': 'Deep thought',
          'searchMetadata': {
            'results': [1, 2, 3],
          },
        };

        final message = ChatMessage.fromMap(map);

        expect(message.text, 'Restored message');
        expect(message.isUser, isFalse);
        expect(message.timestamp, DateTime(2024, 1, 15, 10, 30, 0));
        expect(message.attachmentPaths, ['/path/to/file.pdf']);
        expect(message.thinkingContent, 'Deep thought');
        expect(message.searchMetadata, {
          'results': [1, 2, 3],
        });
      });

      test('should handle null optional fields', () {
        final map = {
          'text': 'Simple message',
          'isUser': true,
          'timestamp': '2024-01-15T10:30:00.000',
        };

        final message = ChatMessage.fromMap(map);

        expect(message.attachmentPaths, isEmpty);
        expect(message.thinkingContent, isNull);
        expect(message.searchMetadata, isNull);
      });

      test('should round-trip correctly', () {
        final original = ChatMessage(
          text: 'Round trip test',
          isUser: true,
          timestamp: DateTime(2024, 1, 15, 10, 30, 0),
          attachmentPaths: ['/a.png', '/b.pdf'],
          thinkingContent: 'Hmm...',
          searchMetadata: {'key': 'value'},
        );

        final restored = ChatMessage.fromMap(original.toMap());

        expect(restored.text, original.text);
        expect(restored.isUser, original.isUser);
        expect(restored.timestamp, original.timestamp);
        expect(restored.attachmentPaths, original.attachmentPaths);
        expect(restored.thinkingContent, original.thinkingContent);
        expect(restored.searchMetadata, original.searchMetadata);
      });
    });

    group('copyWith', () {
      test('should copy with modified fields', () {
        final now = DateTime.now();
        final original = ChatMessage(
          text: 'Original',
          isUser: true,
          timestamp: now,
        );

        final modified = original.copyWith(text: 'Modified');

        expect(modified.text, 'Modified');
        expect(modified.isUser, isTrue);
        expect(modified.timestamp, now);
      });

      test('should preserve unmodified fields', () {
        final original = ChatMessage(
          text: 'Original',
          isUser: false,
          timestamp: DateTime(2024, 1, 1),
          attachmentPaths: ['/test.png'],
          thinkingContent: 'Think',
          searchMetadata: {'q': 'test'},
        );

        final modified = original.copyWith(isUser: true);

        expect(modified.text, 'Original');
        expect(modified.isUser, isTrue);
        expect(modified.attachmentPaths, ['/test.png']);
        expect(modified.thinkingContent, 'Think');
        expect(modified.searchMetadata, {'q': 'test'});
      });
    });
  });
}
