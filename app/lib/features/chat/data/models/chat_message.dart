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

