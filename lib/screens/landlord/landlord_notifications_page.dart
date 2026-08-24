import 'package:flutter/material.dart';

import '../../models/landlord.dart';

class LandlordNotificationsPage extends StatefulWidget {
  final Landlord landlord;

  const LandlordNotificationsPage({
    super.key,
    required this.landlord,
  });

  @override
  State<LandlordNotificationsPage> createState() =>
      _LandlordNotificationsPageState();
}

class _LandlordNotificationsPageState
    extends State<LandlordNotificationsPage> {
  final List<_LandlordNotification> _notifications = [];

  void _createNotification() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Notification'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Water interruption',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Write your notification...',
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
                        'Enter both a title and message.',
                      ),
                    ),
                  );
                  return;
                }

                setState(() {
                  _notifications.insert(
                    0,
                    _LandlordNotification(
                      title: title,
                      message: message,
                      createdAt: DateTime.now(),
                      sender: widget.landlord.fullName,
                    ),
                  );
                });

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Notification created successfully.',
                    ),
                  ),
                );
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNotification,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            widget.landlord.apartmentName.isNotEmpty
                ? widget.landlord.apartmentName
                : 'Apartment Notifications',
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Communicate important updates with your tenants.',
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
                    child: Icon(
                      Icons.campaign_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tenant communication',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Notifications created here are visible to tenants in your apartment.',
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
            'Recent Notifications',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          if (_notifications.isEmpty)
            _emptyState()
          else
            ..._notifications.map(_notificationCard),
        ],
      ),
    );
  }

  Widget _notificationCard(
    _LandlordNotification notification,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: const CircleAvatar(
          child: Icon(Icons.notifications_outlined),
        ),
        title: Text(
          notification.title,
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
              Text(notification.message),
              const SizedBox(height: 6),
              Text(
                '${notification.sender} • ${_formatDate(notification.createdAt)}',
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
              Icons.notifications_none_outlined,
              size: 55,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a notification to communicate an important update to your tenants.',
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

class _LandlordNotification {
  final String title;
  final String message;
  final DateTime createdAt;
  final String sender;

  const _LandlordNotification({
    required this.title,
    required this.message,
    required this.createdAt,
    required this.sender,
  });
}
