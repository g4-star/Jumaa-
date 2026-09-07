import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/landlord.dart';

class LandlordMessagesPage extends StatefulWidget {
  final Landlord landlord;

  const LandlordMessagesPage({
    super.key,
    required this.landlord,
  });

  @override
  State<LandlordMessagesPage> createState() =>
      _LandlordMessagesPageState();
}

class _LandlordMessagesPageState extends State<LandlordMessagesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();

  List<ChatContact> _contacts = [];

  String _search = '';
  bool _loading = true;
  String? _error;

  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  String get _propertyId => widget.landlord.propertyId.trim();

  @override
  void initState() {
    super.initState();

    debugPrint(
      'LANDLORD MESSAGES: initState '
      'landlord=${widget.landlord.fullName} '
      'landlordId=${widget.landlord.id} '
      'property=${widget.landlord.propertyName} '
      'propertyId=$_propertyId '
      'currentUser=$_currentUserId',
    );

    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    if (_currentUserId.isEmpty) {
      debugPrint('LANDLORD MESSAGES: No authenticated user.');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Your session has expired. Please log in again.';
      });

      return;
    }

    if (_propertyId.isEmpty) {
      debugPrint('LANDLORD MESSAGES: Property ID is empty.');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'No property is assigned to this landlord.';
      });

      return;
    }

    try {
      debugPrint(
        'LANDLORD MESSAGES: loading contacts for property=$_propertyId',
      );

      // ------------------------------------------------------------
      // LOAD PROPERTY + OWNER
      // ------------------------------------------------------------
      final propertyRows = await _supabase
          .from('properties')
          .select('id, name, owner_id, landlord_id')
          .eq('id', _propertyId)
          .limit(1);

      if (propertyRows.isEmpty) {
        throw Exception('Property not found.');
      }

      final property = propertyRows.first;
      final ownerId = property['owner_id']?.toString() ?? '';

      debugPrint(
        'LANDLORD MESSAGES: property=${property['name']} '
        'ownerId=$ownerId '
        'landlordId=${property['landlord_id']}',
      );

      // ------------------------------------------------------------
      // LOAD ALL TENANTS
      // ------------------------------------------------------------
      final tenantRows = await _supabase
          .from('tenants')
          .select(
            'id, auth_user_id, full_name, email, phone, '
            'property_id, unit_id',
          )
          .eq('property_id', _propertyId)
          .order('full_name');

      debugPrint(
        'LANDLORD MESSAGES: loaded ${tenantRows.length} tenants',
      );

      // ------------------------------------------------------------
      // LOAD ALL CONVERSATIONS FOR THIS PROPERTY
      // ------------------------------------------------------------
      final conversationRows = await _supabase
          .from('conversations')
          .select('id, property_id, unit_id, created_at')
          .eq('property_id', _propertyId)
          .order('created_at', ascending: false);

      debugPrint(
        'LANDLORD MESSAGES: loaded '
        '${conversationRows.length} conversations',
      );

      // conversation_id -> participant profile IDs
      final Map<String, Set<String>> conversationParticipants = {};

      for (final conversation in conversationRows) {
        final conversationId = conversation['id']?.toString() ?? '';

        if (conversationId.isEmpty) continue;

        try {
          final participants = await _supabase
              .from('conversation_participants')
              .select('profile_id')
              .eq('conversation_id', conversationId);

          conversationParticipants[conversationId] = participants
              .map<String>(
                (row) => row['profile_id']?.toString() ?? '',
              )
              .where((id) => id.isNotEmpty)
              .toSet();
        } catch (e) {
          debugPrint(
            'LANDLORD MESSAGES: participant lookup failed '
            'conversation=$conversationId error=$e',
          );
        }
      }

      // ------------------------------------------------------------
      // HELPER: GET LATEST MESSAGE
      // ------------------------------------------------------------
      Future<String> latestMessage(String? conversationId) async {
        if (conversationId == null || conversationId.isEmpty) {
          return '';
        }

        try {
          final rows = await _supabase
              .from('messages')
              .select('message, created_at, sender_id')
              .eq('conversation_id', conversationId)
              .order('created_at', ascending: false)
              .limit(1);

          if (rows.isNotEmpty) {
            return rows.first['message']?.toString() ?? '';
          }
        } catch (e) {
          debugPrint(
            'LANDLORD MESSAGES: latest message lookup failed '
            'conversation=$conversationId error=$e',
          );
        }

        return '';
      }

      final contacts = <ChatContact>[];

      // ------------------------------------------------------------
      // ADD PROPERTY OWNER
      // ------------------------------------------------------------
      if (ownerId.isNotEmpty && ownerId != _currentUserId) {
        String ownerName = 'Property Owner';
        String ownerEmail = '';
        String ownerPhone = '';

        try {
          final ownerRows = await _supabase
              .from('profiles')
              .select('id, full_name, email, phone')
              .eq('id', ownerId)
              .limit(1);

          if (ownerRows.isNotEmpty) {
            final owner = ownerRows.first;

            final profileName =
                owner['full_name']?.toString().trim() ?? '';

            if (profileName.isNotEmpty) {
              ownerName = profileName;
            }

            ownerEmail = owner['email']?.toString() ?? '';
            ownerPhone = owner['phone']?.toString() ?? '';
          }
        } catch (e) {
          debugPrint(
            'LANDLORD MESSAGES: owner profile lookup failed: $e',
          );
        }

        String? ownerConversationId;

        for (final entry in conversationParticipants.entries) {
          final participantIds = entry.value;

          if (participantIds.contains(_currentUserId) &&
              participantIds.contains(ownerId)) {
            ownerConversationId = entry.key;
            break;
          }
        }

        final ownerLastMessage =
            await latestMessage(ownerConversationId);

        contacts.add(
          ChatContact(
            id: ownerId,
            name: ownerName,
            type: 'Owner',
            unread: false,
            conversationId: ownerConversationId,
            unitId: '',
            email: ownerEmail,
            phone: ownerPhone,
            lastMessage: ownerLastMessage,
          ),
        );

        debugPrint(
          'LANDLORD MESSAGES OWNER CONTACT: '
          'name=$ownerName '
          'ownerId=$ownerId '
          'conversationId=$ownerConversationId '
          'lastMessage=$ownerLastMessage',
        );
      }

      // ------------------------------------------------------------
      // ADD TENANTS
      // ------------------------------------------------------------
      for (final tenant in tenantRows) {
        final tenantAuthId =
            tenant['auth_user_id']?.toString() ?? '';

        final tenantName =
            tenant['full_name']?.toString().trim().isNotEmpty == true
                ? tenant['full_name'].toString().trim()
                : 'Tenant';

        final tenantId = tenant['id']?.toString() ?? '';
        final unitId = tenant['unit_id']?.toString() ?? '';

        String? conversationId;

        if (tenantAuthId.isNotEmpty) {
          for (final entry in conversationParticipants.entries) {
            final participantIds = entry.value;

            if (participantIds.contains(_currentUserId) &&
                participantIds.contains(tenantAuthId)) {
              conversationId = entry.key;
              break;
            }
          }
        }

        final lastMessage = await latestMessage(conversationId);

        contacts.add(
          ChatContact(
            id: tenantAuthId.isNotEmpty
                ? tenantAuthId
                : tenantId,
            name: tenantName,
            type: 'Tenant',
            unread: false,
            conversationId: conversationId,
            unitId: unitId,
            email: tenant['email']?.toString() ?? '',
            phone: tenant['phone']?.toString() ?? '',
            lastMessage: lastMessage,
          ),
        );

        debugPrint(
          'LANDLORD MESSAGES TENANT CONTACT: '
          'name=$tenantName '
          'tenantAuthId=$tenantAuthId '
          'unitId=$unitId '
          'conversationId=$conversationId '
          'lastMessage=$lastMessage',
        );
      }

      if (!mounted) return;

      setState(() {
        _contacts = contacts;
        _loading = false;
      });

      debugPrint(
        'LANDLORD MESSAGES: loaded '
        '${contacts.length} total contacts '
        '(owner + tenants)',
      );
    } catch (e, stackTrace) {
      debugPrint('LANDLORD MESSAGES ERROR: $e');
      debugPrint('LANDLORD MESSAGES STACK: $stackTrace');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Unable to load your messages. Please try again.';
      });
    }
  }

  List<ChatContact> get filteredContacts {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return _contacts;
    }

    return _contacts.where((contact) {
      return contact.name.toLowerCase().contains(query) ||
          contact.email.toLowerCase().contains(query) ||
          contact.unitId.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openChat(ChatContact contact) async {
    if (contact.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This contact does not have a valid account.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LandlordChatPage(
          landlord: widget.landlord,
          contact: contact,
        ),
      ),
    );

    /*
     * Refresh the conversation preview when returning from chat.
     */
    if (result == true && mounted) {
      await _loadContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadContacts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              12,
              18,
              10,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _search = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search tenants',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            _search = '';
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.grey.shade500,
              ),
              const SizedBox(height: 15),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loadContacts,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final contacts = filteredContacts;

    if (contacts.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadContacts,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 4,
        ),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          return _contactTile(contacts[index]);
        },
      ),
    );
  }

  Widget _contactTile(ChatContact contact) {
    final initial = contact.name.trim().isNotEmpty
        ? contact.name.trim().substring(0, 1).toUpperCase()
        : 'T';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: CircleAvatar(
          radius: 24,
          child: Text(
            initial,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          contact.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: contact.lastMessage.isNotEmpty
            ? Text(
                contact.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                contact.type == 'Owner'
                    ? 'Property Owner'
                    : contact.unitId.isNotEmpty
                        ? 'Tenant • Unit ${contact.unitId}'
                        : 'Tenant',
              ),
        trailing: contact.unread
            ? Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              )
            : const Icon(Icons.chevron_right),
        onTap: () => _openChat(contact),
      ),
    );
  }

  Widget _emptyState() {
    final searching = _search.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 65,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 15),
            Text(
              searching
                  ? 'No contact found'
                  : 'No messages yet',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              searching
                  ? 'Try searching with another name or unit.'
                  : 'Your property owner and assigned tenants will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatContact {
  final String id;
  final String name;
  final String type;
  final bool unread;
  final String? conversationId;
  final String unitId;
  final String email;
  final String phone;
  final String lastMessage;

  const ChatContact({
    required this.id,
    required this.name,
    required this.type,
    this.unread = false,
    this.conversationId,
    this.unitId = '',
    this.email = '',
    this.phone = '',
    this.lastMessage = '',
  });
}

class LandlordChatPage extends StatefulWidget {
  final Landlord landlord;
  final ChatContact contact;

  const LandlordChatPage({
    super.key,
    required this.landlord,
    required this.contact,
  });

  @override
  State<LandlordChatPage> createState() => _LandlordChatPageState();
}

class _LandlordChatPageState extends State<LandlordChatPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];

  String? _conversationId;

  bool _loading = true;
  bool _sending = false;
  String? _error;

  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();

    _conversationId = widget.contact.conversationId;

    debugPrint(
      'LANDLORD CHAT: opening '
      'tenant=${widget.contact.name} '
      'tenantId=${widget.contact.id} '
      'conversation=$_conversationId',
    );

    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    if (_currentUserId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Your session has expired. Please log in again.';
      });

      return;
    }

    try {
      /*
       * If no conversation exists yet, the chat can still open.
       * The conversation will be created when the landlord sends
       * the first message.
       */
      if (_conversationId == null || _conversationId!.isEmpty) {
        if (!mounted) return;

        setState(() {
          _messages = [];
          _loading = false;
        });

        return;
      }

      final rows = await _supabase
          .from('messages')
          .select(
            'id, sender_id, receiver_id, conversation_id, '
            'message, created_at, status',
          )
          .eq('conversation_id', _conversationId!)
          .order('created_at', ascending: true);

      final loadedMessages = rows.map<ChatMessage>((row) {
        return ChatMessage(
          id: row['id']?.toString() ?? '',
          senderId: row['sender_id']?.toString() ?? '',
          receiverId: row['receiver_id']?.toString() ?? '',
          conversationId: row['conversation_id']?.toString() ?? '',
          message: row['message']?.toString() ?? '',
          createdAt: DateTime.tryParse(
                row['created_at']?.toString() ?? '',
              ) ??
              DateTime.now(),
          status: row['status']?.toString() ?? 'sent',
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _messages = loadedMessages;
        _loading = false;
      });

      debugPrint(
        'LANDLORD CHAT: loaded ${loadedMessages.length} messages '
        'for conversation=$_conversationId',
      );

      _scrollToBottom();
    } catch (e, stackTrace) {
      debugPrint('LANDLORD CHAT LOAD ERROR: $e');
      debugPrint('LANDLORD CHAT LOAD STACK: $stackTrace');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Unable to load this conversation.';
      });
    }
  }

  Future<String> _getOrCreateConversation() async {
    if (_conversationId != null && _conversationId!.isNotEmpty) {
      return _conversationId!;
    }

    debugPrint(
      'LANDLORD CHAT: creating conversation '
      'property=$_propertyId '
      'receiver=${widget.contact.id}',
    );

    final response = await _supabase.rpc(
      'get_or_create_apartment_conversation',
      params: {
        'p_property_id': _propertyId,
        'p_receiver_id': widget.contact.id,
      },
    );

    String? conversationId;

    if (response is String) {
      conversationId = response;
    } else if (response is Map) {
      conversationId =
          response['id']?.toString() ??
          response['conversation_id']?.toString();
    } else if (response is List && response.isNotEmpty) {
      final first = response.first;

      if (first is String) {
        conversationId = first;
      } else if (first is Map) {
        conversationId =
            first['id']?.toString() ??
            first['conversation_id']?.toString();
      }
    }

    if (conversationId == null || conversationId.isEmpty) {
      throw Exception(
        'The messaging server did not return a conversation ID.',
      );
    }

    _conversationId = conversationId;

    debugPrint(
      'LANDLORD CHAT: conversation ready=$_conversationId',
    );

    return conversationId;
  }

  String get _propertyId => widget.landlord.propertyId.trim();

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    if (_currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your session has expired. Please log in again.'),
        ),
      );

      return;
    }

    if (_propertyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No property is assigned to this landlord.'),
        ),
      );

      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final conversationId = await _getOrCreateConversation();

      debugPrint(
        'LANDLORD CHAT: sending message '
        'sender=$_currentUserId '
        'receiver=${widget.contact.id} '
        'conversation=$conversationId',
      );

      final inserted = await _supabase
          .from('messages')
          .insert({
            'sender_id': _currentUserId,
            'receiver_id': widget.contact.id,
            'conversation_id': conversationId,
            'message': text,
            'status': 'sent',
          })
          .select(
            'id, sender_id, receiver_id, conversation_id, '
            'message, created_at, status',
          )
          .single();

      final newMessage = ChatMessage(
        id: inserted['id']?.toString() ?? '',
        senderId: inserted['sender_id']?.toString() ?? '',
        receiverId: inserted['receiver_id']?.toString() ?? '',
        conversationId:
            inserted['conversation_id']?.toString() ?? '',
        message: inserted['message']?.toString() ?? text,
        createdAt: DateTime.tryParse(
              inserted['created_at']?.toString() ?? '',
            ) ??
            DateTime.now(),
        status: inserted['status']?.toString() ?? 'sent',
      );

      if (!mounted) return;

      setState(() {
        _messages.add(newMessage);
        _sending = false;
      });

      _messageController.clear();
      _scrollToBottom();

      debugPrint(
        'LANDLORD CHAT: message sent successfully '
        'id=${newMessage.id}',
      );
    } catch (e, stackTrace) {
      debugPrint('LANDLORD CHAT SEND ERROR: $e');
      debugPrint('LANDLORD CHAT SEND STACK: $stackTrace');

      if (!mounted) return;

      setState(() {
        _sending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not send message: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.contact.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.contact.type == 'Owner'
                  ? 'Property Owner'
                  : widget.contact.unitId.isNotEmpty
                      ? 'Tenant • Unit ${widget.contact.unitId}'
                      : 'Tenant',
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadMessages,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesBody(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Write a message...',
                        suffixIcon: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _sendMessage,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.grey.shade500,
              ),
              const SizedBox(height: 15),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            'Start a conversation with '
            '${widget.contact.name}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(18),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];

          final isMine = message.senderId == _currentUserId;

          return Align(
            alignment:
                isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: isMine
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.message,
                    style: TextStyle(
                      color: isMine
                          ? Colors.white
                          : Theme.of(context)
                              .colorScheme
                              .onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMine
                          ? Colors.white70
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String conversationId;
  final String message;
  final DateTime createdAt;
  final String status;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.conversationId,
    required this.message,
    required this.createdAt,
    required this.status,
  });
}
