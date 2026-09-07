import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/chat_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();

  final List<Map<String, dynamic>> _landlords = [];

  bool _loading = true;
  bool _openingChat = false;

  String get _currentUserId =>
      OpenNestStore.supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadOwnerLandlords();
  }

  Future<void> _loadOwnerLandlords() async {
    if (_currentUserId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final propertyResponse = await OpenNestStore.supabase
          .from('properties')
          .select('id, name, landlord_id')
          .eq('owner_id', _currentUserId);

      final properties =
          List<Map<String, dynamic>>.from(propertyResponse);

      _landlords.clear();

      final Map<String, Map<String, dynamic>> landlordProperties = {};

      for (final property in properties) {
        final landlordId = property['landlord_id']?.toString() ?? '';

        if (landlordId.isEmpty) continue;

        landlordProperties[landlordId] = {
          'property_id': property['id']?.toString() ?? '',
          'property_name':
              property['name']?.toString() ?? 'Property',
        };
      }

      if (landlordProperties.isNotEmpty) {
        final landlordResponse = await OpenNestStore.supabase
            .from('landlords')
            .select('id, full_name, email, phone')
            .inFilter(
              'id',
              landlordProperties.keys.toList(),
            );

        for (final row in landlordResponse) {
          final landlord = Map<String, dynamic>.from(row);
          final landlordId = landlord['id']?.toString() ?? '';

          final property = landlordProperties[landlordId];

          if (landlordId.isEmpty || property == null) continue;

          _landlords.add({
            'id': landlordId,
            'name':
                landlord['full_name']?.toString() ?? 'Landlord',
            'email': landlord['email']?.toString() ?? '',
            'phone': landlord['phone']?.toString() ?? '',
            'property_id': property['property_id'],
            'property_name': property['property_name'],
          });
        }
      }

      _landlords.sort(
        (a, b) => (a['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(
              (b['name'] ?? '')
                  .toString()
                  .toLowerCase(),
            ),
      );

      debugPrint(
        'OWNER MESSAGES UI: loaded ${_landlords.length} landlord(s)',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('OWNER MESSAGES ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load messages: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openLandlord(
    Map<String, dynamic> landlord,
  ) async {
    if (_openingChat) return;

    final landlordId = landlord['id']?.toString() ?? '';
    final propertyId =
        landlord['property_id']?.toString() ?? '';

    if (landlordId.isEmpty || propertyId.isEmpty) {
      return;
    }

    setState(() {
      _openingChat = true;
    });

    try {
      final conversationId =
          await _chatService.getOrCreateConversation(
        propertyId: propertyId,
        landlordId: landlordId,
      );

      if (!mounted) return;

      if (conversationId.isEmpty) {
        throw Exception(
          'Could not create the conversation.',
        );
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TenantChatConversationScreen(
            conversationId: conversationId,
            currentUserId: _currentUserId,
            contact: {
              'id': landlordId,
              'profile_id': landlordId,
              'name': landlord['name'] ?? 'Landlord',
              'email': landlord['email'] ?? '',
              'phone': landlord['phone'] ?? '',
              'type': 'landlord',
            },
            propertyId: propertyId,
          ),
        ),
      );

      await _loadOwnerLandlords();
    } catch (e) {
      debugPrint('OWNER OPEN CHAT ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open chat: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingChat = false;
        });
      }
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'L';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildAvatar(
    Map<String, dynamic> landlord,
    bool isDark,
  ) {
    final name =
        landlord['name']?.toString() ?? 'Landlord';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 29,
          backgroundColor: isDark
              ? const Color(0xFF176B5F)
              : const Color(0xFFE1F2EE),
          child: Text(
            _initials(name),
            style: TextStyle(
              color: isDark
                  ? Colors.white
                  : const Color(0xFF075E54),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Positioned(
          right: -1,
          bottom: 1,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF20C55A),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Theme.of(context).scaffoldBackgroundColor
                    : Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandlordTile(
    Map<String, dynamic> landlord,
    bool isDark,
  ) {
    final name =
        landlord['name']?.toString() ?? 'Landlord';

    final property =
        landlord['property_name']?.toString() ??
        'Property';

    final email =
        landlord['email']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openingChat
            ? null
            : () => _openLandlord(landlord),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 9,
          ),
          child: Row(
            children: [
              _buildAvatar(landlord, isDark),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(
                                      0xFF18201E,
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          'Landlord',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w600,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Icon(
                          Icons.apartment_rounded,
                          size: 15,
                          color: isDark
                              ? Colors.white54
                              : const Color(
                                  0xFF075E54,
                                ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            property,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w500,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white38
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? Colors.white38
                    : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadOwnerLandlords,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),

          Container(
            width: 105,
            height: 105,
            margin: const EdgeInsets.symmetric(
              horizontal: 135,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF173F3A)
                  : const Color(0xFFE8F5F2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.forum_outlined,
              size: 48,
              color: isDark
                  ? const Color(0xFF7FD8CB)
                  : const Color(0xFF075E54),
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              'No landlords to message',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? Colors.white
                    : const Color(0xFF18201E),
              ),
            ),
          ),

          const SizedBox(height: 9),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 45,
            ),
            child: Text(
              'Landlords assigned to your properties '
              'will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark
                    ? Colors.white54
                    : Colors.grey.shade600,
              ),
            ),
          ),

          const SizedBox(height: 22),

          Center(
            child: TextButton.icon(
              onPressed: _loadOwnerLandlords,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF101514)
          : const Color(0xFFF7F9F8),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF101514)
            : const Color(0xFFF7F9F8),
        surfaceTintColor: Colors.transparent,

        titleSpacing: 20,

        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Messages',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? Colors.white
                    : const Color(0xFF18201E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Connect with your landlords',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? Colors.white54
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _loading ? null : _loadOwnerLandlords,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _landlords.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _loadOwnerLandlords,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      18,
                      16,
                      30,
                    ),
                    children: [
                      Row(
                        children: [
                          Text(
                            'Your landlords',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(
                                      0xFF18201E,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(
                                      0xFF173F3A,
                                    )
                                  : const Color(
                                      0xFFE1F2EE,
                                    ),
                              borderRadius:
                                  BorderRadius.circular(
                                20,
                              ),
                            ),
                            child: Text(
                              '${_landlords.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.bold,
                                color: isDark
                                    ? const Color(
                                        0xFF8DE0D4,
                                      )
                                    : const Color(
                                        0xFF075E54,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      Text(
                        'Only landlords managing your properties '
                        'are shown here.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 13),

                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF17201F)
                              : Colors.white,
                          borderRadius:
                              BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 15,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Private owner-to-landlord conversations',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF151C1B)
                              : Colors.white,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: _landlords
                              .map(
                                (landlord) =>
                                    _buildLandlordTile(
                                  landlord,
                                  isDark,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
