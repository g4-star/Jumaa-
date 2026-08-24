import 'message.dart';

class Conversation {
  final String id;
  final String? propertyId;
  final List<String> participantIds;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final List<Message>? recentMessages;

  Conversation({
    required this.id,
    this.propertyId,
    required this.participantIds,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
    this.recentMessages,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      propertyId: map['property_id'] as String?,
      participantIds:
          (map['participant_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      lastMessage: map['last_message'] as String?,
      lastMessageAt: map['last_message_at'] != null
          ? DateTime.parse(map['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
