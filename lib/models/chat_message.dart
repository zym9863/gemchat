class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? mediaType; // 媒体类型：image, audio等
  final String? mediaPath; // 媒体文件路径

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.mediaType,
    this.mediaPath,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromUser(String content, {String? mediaType, String? mediaPath}) {
    return ChatMessage(
      content: content,
      isUser: true,
      mediaType: mediaType,
      mediaPath: mediaPath,
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
      'mediaType': mediaType,
      'mediaPath': mediaPath,
    };
  }
  
  // 从JSON反序列化
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'],
      isUser: json['isUser'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      mediaType: json['mediaType'],
      mediaPath: json['mediaPath'],
    );
  }
}