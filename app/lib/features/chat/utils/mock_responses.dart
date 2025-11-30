import '../../../../app/constants/app_constants.dart';

/// Utility class for generating mock responses in test mode
class MockResponses {
  /// Get a mock response based on the configured response type
  /// [messageCount] is used for cycling through default responses
  static String getMockResponse(String prompt, int messageCount) {
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
        return responses[messageCount % responses.length];
    }
  }
}

