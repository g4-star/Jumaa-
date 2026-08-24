import 'package:flutter/material.dart';

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

class _LandlordMessagesPageState
    extends State<LandlordMessagesPage> {
  final TextEditingController _searchController =
      TextEditingController();

  final List<ChatContact> _contacts = [];

  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChatContact> get filteredContacts {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return _contacts;
    }

    return _contacts.where((contact) {
      return contact.name.toLowerCase().contains(query);
    }).toList();
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
                hintText: 'Search by name',
                prefixIcon: const Icon(
                  Icons.search,
                ),
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
            child: filteredContacts.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                    ),
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact =
                          filteredContacts[index];

                      return _contactTile(contact);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _contactTile(ChatContact contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            contact.name
                .substring(0, 1)
                .toUpperCase(),
          ),
        ),
        title: Text(
          contact.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(contact.type),
        trailing: contact.unread
            ? Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              )
            : const Icon(
                Icons.chevron_right,
              ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LandlordChatPage(
                landlord: widget.landlord,
                contact: contact,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 65,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 15),
            const Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _search.isEmpty
                  ? 'Your conversations with the admin and tenants will appear here.'
                  : 'No person found with that name.',
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

  const ChatContact({
    required this.id,
    required this.name,
    required this.type,
    this.unread = false,
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
  State<LandlordChatPage> createState() =>
      _LandlordChatPageState();
}

class _LandlordChatPageState
    extends State<LandlordChatPage> {
  final TextEditingController _messageController =
      TextEditingController();

  final List<String> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(text);
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              widget.contact.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.contact.type,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Start a conversation with '
                      '${widget.contact.name}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return Align(
                        alignment:
                            Alignment.centerRight,
                        child: Container(
                          margin:
                              const EdgeInsets.only(
                            bottom: 10,
                          ),
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                          child: Text(
                            _messages[index],
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
                      controller:
                          _messageController,
                      textInputAction:
                          TextInputAction.send,
                      onSubmitted: (_) =>
                          _sendMessage(),
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Write a message...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(
                      Icons.send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
