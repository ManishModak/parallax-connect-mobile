import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/connectivity_service.dart';
import '../../../core/storage/chat_archive_storage.dart';
import '../../../core/storage/chat_history_storage.dart';
import '../../../core/storage/config_storage.dart';
import '../../settings/data/settings_storage.dart';
import '../../../core/utils/logger.dart';
import '../data/chat_repository.dart';

import '../../../core/constants/app_constants.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> attachmentPaths;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.attachmentPaths = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'attachmentPaths': attachmentPaths,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'],
      isUser: map['isUser'],
      timestamp: DateTime.parse(map['timestamp']),
      attachmentPaths: List<String>.from(map['attachmentPaths'] ?? []),
    );
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final bool isPrivateMode;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.isPrivateMode = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    bool? isPrivateMode,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isPrivateMode: isPrivateMode ?? this.isPrivateMode,
    );
  }
}

class ChatController extends Notifier<ChatState> {
  late final ChatRepository _repository;
  late final ChatHistoryStorage _historyStorage;
  late final ChatArchiveStorage _archiveStorage;
  late final ConnectivityService _connectivityService;
  late final ConfigStorage _configStorage;
  late final SettingsStorage _settingsStorage;

  @override
  ChatState build() {
    _repository = ref.read(chatRepositoryProvider);
    _historyStorage = ref.read(chatHistoryStorageProvider);
    _archiveStorage = ref.read(chatArchiveStorageProvider);
    _connectivityService = ref.read(connectivityServiceProvider);
    _configStorage = ref.read(configStorageProvider);
    _settingsStorage = ref.read(settingsStorageProvider);

    // Load history and return initial state with messages
    final history = _historyStorage.getHistory();
    final messages = history.map((e) => ChatMessage.fromMap(e)).toList();

    return ChatState(messages: messages);
  }

  Future<void> startNewChat() async {
    // Archive current chat session before clearing
    // Only archive if there are messages and not in private mode
    if (state.messages.isNotEmpty && !state.isPrivateMode) {
      try {
        final messageMaps = state.messages.map((m) => m.toMap()).toList();
        await _archiveStorage.archiveSession(messages: messageMaps);
        logger.i('Chat session archived before starting new chat');
      } catch (e) {
        logger.e('Failed to archive session: $e');
        // Continue with clearing even if archiving fails
      }
    }

    await clearHistory();
  }

  void togglePrivateMode() {
    final newMode = !state.isPrivateMode;
    state = state.copyWith(
      isPrivateMode: newMode,
      messages: newMode ? [] : state.messages, // Clear messages when enabling
      error: null,
    );
  }

  void disablePrivateMode() {
    state = state.copyWith(isPrivateMode: false, messages: [], error: null);
  }

  Future<void> sendMessage(
    String text, {
    List<String> attachmentPaths = const [],
  }) async {
    if (text.trim().isEmpty && attachmentPaths.isEmpty) return;

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      attachmentPaths: attachmentPaths,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    // Only save to history if not in private mode
    if (!state.isPrivateMode) {
      await _historyStorage.saveMessage(userMessage.toMap());
    }

    try {
      String response;

      // 🧪 In test mode, use mock responses
      if (TestConfig.enabled) {
        await Future.delayed(
          const Duration(seconds: 2),
        ); // Simulate network delay
        response = _getMockResponse(text);
      } else {
        // Check connectivity for cloud mode
        final isLocal = _configStorage.getIsLocal();
        if (!isLocal) {
          final hasInternet = await _connectivityService.hasInternetConnection;
          if (!hasInternet) {
            throw Exception(
              'No internet connection. Cloud mode requires an active connection.',
            );
          }
        }

        final systemPrompt = _settingsStorage.getSystemPrompt();
        response = await _repository.generateText(
          text,
          systemPrompt: systemPrompt,
        );
      }

      final aiMessage = ChatMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isLoading: false,
      );

      // Only save to history if not in private mode
      if (!state.isPrivateMode) {
        await _historyStorage.saveMessage(aiMessage.toMap());
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> clearHistory() async {
    await _historyStorage.clearHistory();
    state = state.copyWith(messages: []);
  }

  // 🧪 Mock responses for test mode
  String _getMockResponse(String prompt) {
    switch (TestConfig.mockResponseType) {
      case 'plain':
        return 'This is a simple plain text response without any formatting. You can use this to test basic message rendering and scrolling behavior.';

      case 'code':
        return '''Here's a code snippet example:

```dart
void main() {
  print("Hello, Parallax!");
}
```

You can test the **Copy Code** button by clicking on it. The syntax highlighting should work once you connect to the real backend.

Here's another snippet:

```python
def greet(name):
    return f"Hello, {name}!"

print(greet("World"))
```

And a longer JavaScript example:

```javascript
class UserManager {
  constructor() {
    this.users = [];
  }

  addUser(name, email) {
    const user = {
      id: this.users.length + 1,
      name: name,
      email: email,
      createdAt: new Date()
    };
    this.users.push(user);
    return user;
  }

  findUser(id) {
    return this.users.find(u => u.id === id);
  }

  getAllUsers() {
    return this.users;
  }
}

// Usage example
const manager = new UserManager();
manager.addUser("John Doe", "john@example.com");
manager.addUser("Jane Smith", "jane@example.com");

console.log(manager.getAllUsers());
```

Try copying these code blocks!''';

      case 'markdown':
        return '''Let me show you **markdown formatting**:

## Heading 2
### Heading 3

**Bold text** and *italic text* work great.

> This is a blockquote
> It can span multiple lines

Here's a list:
1. First item
2. Second item
3. Third item

And an unordered list:
- Item one
- Item two
- Item three

You can also use `inline code` like this.''';

      case 'mixed':
        return '''# Mixed Content Response

This response contains **everything** to test all features at once!

## Code Example

```javascript
const greeting = "Hello, World!";
console.log(greeting);
```

## Formatted Text

Here's some **bold**, *italic*, and `inline code`.

> Important: This is a blockquote with useful information.

## Lists

1. **First feature** - Copy code button
2. **Second feature** - Copy all button  
3. **Third feature** - Markdown rendering

Try the copy buttons! Click "Copy Code" on the snippet or "Copy All" at the bottom.''';

      case 'long':
        return '''# Long Response for Scroll Testing

This is a very long response to test scrolling behavior and how the UI handles extensive content.

## Section 1: Introduction

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

## Section 2: Code Examples

Here's a comprehensive code example:

```dart
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Counter App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('You have pushed the button this many times:'),
            Text(
              '\$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## Section 3: Features

1. **Copy functionality** - Test the copy buttons
2. **Markdown rendering** - See how it formats
3. **Scroll behavior** - Long content scrolling
4. **Attachment support** - Try adding images

## Section 4: Conclusion

This long response helps you verify that:
- The chat scrolls smoothly
- Code blocks are properly highlighted  
- Copy buttons work correctly
- The UI remains responsive with long content

**Try scrolling** through this message and testing all the interactive elements!''';

      default:
        // Cycle through variations if type not recognized
        final responses = [
          'This is a **test response** from the AI assistant.',
          'Great! The UI is working perfectly. Try different features! 🚀',
          'You can change `TestConfig.mockResponseType` in `app_constants.dart` to test different response types like: `plain`, `code`, `markdown`, `mixed`, or `long`.',
        ];
        return responses[state.messages.length % responses.length];
    }
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(() {
  return ChatController();
});
