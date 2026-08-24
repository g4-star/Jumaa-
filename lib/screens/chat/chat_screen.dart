import 'package:flutter/material.dart';

import '../../models/message.dart';
import '../../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String propertyId;
  final String? unitId;
  final String landlordId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.propertyId,
    this.unitId,
    required this.landlordId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];

  String? _conversationId;
  bool _loading = true;
  bool _sending = false;

  String get _currentUserId {
    final id = _chatService.currentUserId;

    if (id == null) {
      throw Exception('You must be logged in to chat.');
    }

    return id;
  }

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final conversationId = await _chatService.getOrCreateConversation(
        propertyId: widget.propertyId,
        unitId: widget.unitId,
        landlordId: widget.landlordId,
      );

      if (!mounted) return;

      setState(() {
        _conversationId = conversationId;
      });

      await _loadMessages(conversationId);
      _subscribeToMessages(conversationId);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open chat: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadMessages(String conversationId) async {
    try {
      final messages = await _chatService.getMessages(
        conversationId: conversationId,
      );

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _loading = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load messages: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _subscribeToMessages(String conversationId) {
    _chatService.subscribeToMessages(conversationId: conversationId).listen((
      message,
    ) {
      if (!mounted) return;

      final alreadyExists = _messages.any(
        (existing) => existing.id == message.id,
      );

      if (alreadyExists) return;

      setState(() {
        _messages.add(message);
      });

      _scrollToBottom();

      if (message.senderId != _currentUserId) {
        _chatService.markDelivered(message.id);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    final conversationId = _conversationId;

    if (conversationId == null) {
      return;
    }

    _messageController.clear();

    setState(() {
      _sending = true;
    });

    try {
      await _chatService.sendMessage(
        conversationId: conversationId,
        receiverId: widget.landlordId,
        message: text,
      );
    } catch (e) {
      if (!mounted) return;

      _messageController.text = text;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.otherUserName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Text(
                      'Send a message to start chatting',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];

                      final isMe = message.senderId == _currentUserId;

                      return _messageBubble(message, isMe, isDark);
                    },
                  ),
          ),
          _buildMessageInput(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.attach_file), onPressed: () {}),
            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              child: IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                onPressed: _sending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(Message message, bool isMe, bool isDark) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.primary
              : isDark
              ? Colors.grey.shade800
              : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : isDark
                    ? Colors.white
                    : Colors.black87,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey.shade500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}
