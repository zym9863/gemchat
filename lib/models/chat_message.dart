class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromUser(String content) {
    return ChatMessage(
      content: content,
      isUser: true,
    );
  }

  factory ChatMessage.fromAI(String content) {
    return ChatMessage(
      content: content,
      isUser: false,
    );
  }
}