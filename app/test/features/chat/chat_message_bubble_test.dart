import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:parallax_connect/core/interfaces/haptics_settings.dart';
import 'package:parallax_connect/core/utils/haptics_helper.dart';
import 'package:parallax_connect/features/chat/models/chat_message.dart';
import 'package:parallax_connect/features/chat/presentation/widgets/messages/chat_message_bubble.dart';

// Mock implementation of HapticsSettings
class MockHapticsSettings implements HapticsSettings {
  @override
  String getHapticsLevel() {
    return 'none';
  }
}

void main() {
  group('ChatMessageBubble', () {
    testWidgets('shows tooltips for action icons when user message is tapped', (
      WidgetTester tester,
    ) async {
      final message = ChatMessage(
        text: 'Hello World',
        isUser: true,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hapticsSettingsProvider.overrideWithValue(MockHapticsSettings()),
          ],
          child: MaterialApp(
            home: Scaffold(child: ChatMessageBubble(message: message)),
          ),
        ),
      );

      // Verify message is displayed
      expect(find.text('Hello World'), findsOneWidget);

      // Action icons should be hidden initially
      expect(find.byIcon(LucideIcons.pencil), findsNothing);
      expect(find.byIcon(LucideIcons.refreshCw), findsNothing);

      // Tap the message to show options
      await tester.tap(find.text('Hello World'));
      await tester.pumpAndSettle();

      // Verify icons are now visible
      expect(find.byIcon(LucideIcons.pencil), findsOneWidget);
      expect(find.byIcon(LucideIcons.refreshCw), findsOneWidget);

      // Verify tooltips
      final editButton = find.ancestor(
        of: find.byIcon(LucideIcons.pencil),
        matching: find.byType(Tooltip),
      );
      final retryButton = find.ancestor(
        of: find.byIcon(LucideIcons.refreshCw),
        matching: find.byType(Tooltip),
      );

      expect(editButton, findsOneWidget, reason: 'Edit button should be wrapped in Tooltip');
      expect(retryButton, findsOneWidget, reason: 'Retry button should be wrapped in Tooltip');

      expect(
        tester.widget<Tooltip>(editButton).message,
        'Edit',
      );
      expect(
        tester.widget<Tooltip>(retryButton).message,
        'Retry',
      );
    });
  });
}
