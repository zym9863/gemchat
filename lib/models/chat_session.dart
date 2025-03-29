import 'chat_message.dart';

class ChatSession {
  final String id;
  final String title;
  final List<dynamic> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
  });

  factory ChatSession.create(String title) {
    final now = DateTime.now();
    return ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      messages: [],
      createdAt: now,
      updatedAt: now,
      isPinned: false,
    );
  }

  ChatSession copyWith({
    String? title,
    List<dynamic>? messages,
    DateTime? updatedAt,
    bool? isPinned,
  }) {
    return ChatSession(
      id: this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isPinned: isPinned ?? this.isPinned,
    );
  }
  
  // 序列化为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((msg) => msg is ChatMessage ? msg.toJson() : msg).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isPinned': isPinned,
    };
  }
  
  // 从JSON反序列化
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      messages: (json['messages'] as List)
          .map((msgJson) => ChatMessage.fromJson(msgJson))
          .toList(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt']),
      isPinned: json['isPinned'] ?? false,
    );
  }
}