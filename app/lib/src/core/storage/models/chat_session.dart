class ChatSession {
  final String id;
  final String title;
  final List<Map<String, dynamic>> messages;
  final DateTime timestamp;
  final int messageCount;
  final bool isImportant;

  const ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.timestamp,
    required this.messageCount,
    this.isImportant = false,
  });

  ChatSession copyWith({
    String? id,
    String? title,
    List<Map<String, dynamic>>? messages,
    DateTime? timestamp,
    int? messageCount,
    bool? isImportant,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      timestamp: timestamp ?? this.timestamp,
      messageCount: messageCount ?? this.messageCount,
      isImportant: isImportant ?? this.isImportant,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'messages': messages,
      'timestamp': timestamp.toIso8601String(),
      'messageCount': messageCount,
      'isImportant': isImportant,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] as String,
      title: map['title'] as String,
      messages: List<Map<String, dynamic>>.from(
        (map['messages'] as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
      messageCount: map['messageCount'] as int,
      isImportant: map['isImportant'] as bool? ?? false,
    );
  }
}
