class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String conversationId;
  final String message;
  final String status;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.conversationId,
    required this.message,
    required this.status,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'].toString(),
      senderId: map['sender_id'].toString(),
      receiverId: map['receiver_id'].toString(),
      conversationId: map['conversation_id'].toString(),
      message: map['message'].toString(),
      status: map['status'].toString(),
      createdAt: DateTime.parse(map['created_at'].toString()),
      deliveredAt: map['delivered_at'] == null
          ? null
          : DateTime.parse(map['delivered_at'].toString()),
      readAt: map['read_at'] == null
          ? null
          : DateTime.parse(map['read_at'].toString()),
    );
  }
}
