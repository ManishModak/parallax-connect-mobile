import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parallax_connect/features/chat/presentation/widgets/chat_input_area.dart';

void main() {
  testWidgets('ChatInputArea has keyboard shortcuts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChatInputArea(
              onSubmitted: (_, __) {},
              isLoading: false,
              onCameraTap: () async => null,
              onGalleryTap: () async => [],
              onFileTap: () async => [],
            ),
          ),
        ),
      ),
    );

    // Verify that CallbackShortcuts is wrapping the TextField (or present in the tree)
    expect(find.byType(CallbackShortcuts), findsOneWidget);

    // Verify that we have a TextField
    expect(find.byType(TextField), findsOneWidget);
  });
}
