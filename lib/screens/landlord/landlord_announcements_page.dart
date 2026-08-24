import 'package:flutter/material.dart';

import '../../models/landlord.dart';

class LandlordAnnouncementsPage extends StatefulWidget {
  final Landlord landlord;

  const LandlordAnnouncementsPage({
    super.key,
    required this.landlord,
  });

  @override
  State<LandlordAnnouncementsPage> createState() =>
      _LandlordAnnouncementsPageState();
}

class _LandlordAnnouncementsPageState
    extends State<LandlordAnnouncementsPage> {
  final List<_Announcement> _announcements = [];

  void _createAnnouncement() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Announcement title',
                    hintText: 'e.g. Monthly meeting',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: messageController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Announcement',
                    hintText: 'Write your announcement...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                final message = messageController.text.trim();

                if (title.isEmpty || message.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter both a title and announcement.',
                      ),
                    ),
                  );
                  return;
                }

                setState(() {
                  _announcements.insert(
                    0,
                    _Announcement(
                      title: title,
                      message: message,
                      createdAt: DateTime.now(),
                      expiresAt: DateTime.now().add(
                        const Duration(days: 14),
                      ),
                      author: widget.landlord.fullName,
                    ),
                  );
                });

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Announcement created successfully.',
                    ),
                  ),
                );
              },
              child: const Text('Publish'),
            ),
          ],
        );
      },
    );
  }

  List<_Announcement> get activeAnnouncements {
    final now = DateTime.now();

    return _announcements
        .where((announcement) =>
            announcement.expiresAt.isAfter(now))
        .toList();
  }

  List<_Announcement> get expiredAnnouncements {
    final now = DateTime.now();

    return _announcements
        .where((announcement) =>
            !announcement.expiresAt.isAfter(now))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Announcements',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createAnnouncement,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            widget.landlord.apartmentName.isNotEmpty
                ? widget.landlord.apartmentName
                : 'Apartment Announcements',
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Important announcements shared with everyone in this apartment.',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 22),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.campaign_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Apartment-wide announcements',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Announcements are visible to all members of this apartment and automatically expire after 14 days.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Active Announcements',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          if (activeAnnouncements.isEmpty)
            _emptyState()
          else
            ...activeAnnouncements.map(
              _announcementCard,
            ),

          if (expiredAnnouncements.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Expired',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...expiredAnnouncements.map(
              (announcement) => Opacity(
                opacity: 0.55,
                child: _announcementCard(
                  announcement,
                  expired: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _announcementCard(
    _Announcement announcement, {
    bool expired = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          child: Icon(
            expired
                ? Icons.history
                : Icons.campaign_outlined,
          ),
        ),
        title: Text(
          announcement.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(announcement.message),
              const SizedBox(height: 8),
              Text(
                'By ${announcement.author}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                expired
                    ? 'Expired'
                    : 'Expires ${_formatDate(announcement.expiresAt)}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 55,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Text(
              'No announcements',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create an announcement to share an important update with apartment members.',
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _Announcement {
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String author;

  const _Announcement({
    required this.title,
    required this.message,
    required this.createdAt,
    required this.expiresAt,
    required this.author,
  });
}
