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
  
  // 序列化为JSON
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
  
  // 从JSON反序列化
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'],
      isUser: json['isUser'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }
}