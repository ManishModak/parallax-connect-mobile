class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> attachmentPaths;

  final String? thinkingContent;
  final Map<String, dynamic>? searchMetadata;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.attachmentPaths = const [],
    this.thinkingContent,
    this.searchMetadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'attachmentPaths': attachmentPaths,
      'thinkingContent': thinkingContent,
      'searchMetadata': searchMetadata,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'],
      isUser: map['isUser'],
      timestamp: DateTime.parse(map['timestamp']),
      attachmentPaths: List<String>.from(map['attachmentPaths'] ?? []),
      thinkingContent: map['thinkingContent'],
      searchMetadata: map['searchMetadata'],
    );
  }

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<String>? attachmentPaths,
    String? thinkingContent,
    Map<String, dynamic>? searchMetadata,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      searchMetadata: searchMetadata ?? this.searchMetadata,
    );
  }
}
