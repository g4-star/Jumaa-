class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String contentType; // 'text', 'image', 'system'
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.contentType = 'text',
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String? ?? '',
      contentType: map['content_type'] as String? ?? 'text',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'content_type': contentType,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
