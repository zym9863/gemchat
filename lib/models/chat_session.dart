class ChatSession {
  final String id;
  final String title;
  final List<dynamic> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.create(String title) {
    final now = DateTime.now();
    return ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      messages: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  ChatSession copyWith({
    String? title,
    List<dynamic>? messages,
    DateTime? updatedAt,
  }) {
    return ChatSession(
      id: this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}