import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';

class ChatService {
  final SupabaseClient supabase = Supabase.instance.client;

  RealtimeChannel? _channel;

  String? get currentUserId {
    return supabase.auth.currentUser?.id;
  }

  // ============================================================
  // FIND OR CREATE CONVERSATION
  // ============================================================

  Future<String> getOrCreateConversation({
    required String propertyId,
    String? unitId,
    required String landlordId,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('You must be logged in to chat.');
    }

    final existing = await supabase
        .from('conversations')
        .select('id, conversation_participants!inner(profile_id)')
        .eq('property_id', propertyId)
        .eq('conversation_participants.profile_id', userId)
        .limit(1);

    if (existing.isNotEmpty) {
      return existing.first['id'].toString();
    }

    final conversation = await supabase
        .from('conversations')
        .insert({'property_id': propertyId, 'unit_id': unitId})
        .select('id')
        .single();

    final conversationId = conversation['id'].toString();

    await supabase.from('conversation_participants').insert([
      {'conversation_id': conversationId, 'profile_id': userId},
      {'conversation_id': conversationId, 'profile_id': landlordId},
    ]);

    return conversationId;
  }

  // ============================================================
  // LOAD MESSAGES
  // ============================================================

  Future<List<Message>> getMessages({required String conversationId}) async {
    final response = await supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return response.map<Message>((row) {
      return Message(
        id: row['id'].toString(),
        conversationId: row['conversation_id'].toString(),
        senderId: row['sender_id'].toString(),
        content: row['message'].toString(),
        contentType: 'text',
        createdAt: DateTime.parse(row['created_at'].toString()),
      );
    }).toList();
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> sendMessage({
    required String conversationId,
    required String receiverId,
    required String message,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('You must be logged in to send messages.');
    }

    final text = message.trim();

    if (text.isEmpty) {
      return;
    }

    await supabase.from('messages').insert({
      'sender_id': userId,
      'receiver_id': receiverId,
      'conversation_id': conversationId,
      'message': text,
      'status': 'sent',
    });
  }

  // ============================================================
  // REALTIME MESSAGES
  // ============================================================

  Stream<Message> subscribeToMessages({required String conversationId}) {
    final controller = StreamController<Message>();

    _channel = supabase
        .channel('conversation_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final row = payload.newRecord;

            if (row['conversation_id'].toString() != conversationId) {
              return;
            }

            controller.add(
              Message(
                id: row['id'].toString(),
                conversationId: row['conversation_id'].toString(),
                senderId: row['sender_id'].toString(),
                content: row['message'].toString(),
                contentType: 'text',
                createdAt: DateTime.parse(row['created_at'].toString()),
              ),
            );
          },
        )
        .subscribe();

    return controller.stream;
  }

  // ============================================================
  // MARK DELIVERED
  // ============================================================

  Future<void> markDelivered(String messageId) async {
    await supabase
        .from('messages')
        .update({
          'status': 'delivered',
          'delivered_at': DateTime.now().toIso8601String(),
        })
        .eq('id', messageId);
  }

  // ============================================================
  // MARK READ
  // ============================================================

  Future<void> markRead(String messageId) async {
    await supabase
        .from('messages')
        .update({'status': 'read', 'read_at': DateTime.now().toIso8601String()})
        .eq('id', messageId);
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  Future<void> dispose() async {
    if (_channel != null) {
      await supabase.removeChannel(_channel!);
      _channel = null;
    }
  }
}
