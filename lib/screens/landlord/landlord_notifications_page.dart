import 'package:flutter/material.dart';

import '../../models/landlord.dart';
import '../../main.dart' show OpenNestStore;

class LandlordNotificationsPage extends StatefulWidget {
  final Landlord landlord;

  const LandlordNotificationsPage({super.key, required this.landlord});

  @override
  State<LandlordNotificationsPage> createState() =>
      _LandlordNotificationsPageState();
}

class _LandlordNotificationsPageState extends State<LandlordNotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  bool _creating = false;

  String get propertyId => widget.landlord.propertyId;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (propertyId.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final response = await OpenNestStore.supabase
          .from('notifications')
          .select('''
            id,
            user_id,
            property_id,
            title,
            message,
            type,
            is_read,
            sender_type,
            sender_name,
            created_at
          ''')
          .eq('property_id', propertyId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      debugPrint('LANDLORD NOTIFICATIONS LOAD ERROR: $e');

      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load notifications: $e')),
      );
    }
  }

  Future<void> _createNotification() async {
    if (propertyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your apartment could not be identified.'),
        ),
      );
      return;
    }

    final user = OpenNestStore.supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your landlord account session has expired.'),
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final messageController = TextEditingController();

    await showDialog(
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
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Water interruption',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: messageController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Write your notification...',
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _creating ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: _creating
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final message = messageController.text.trim();

                      if (title.isEmpty || message.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter both a title and message.'),
                          ),
                        );
                        return;
                      }

                      setState(() => _creating = true);

                      try {
                        await OpenNestStore.supabase
                            .from('notifications')
                            .insert({
                              'user_id': user.id,
                              'property_id': propertyId,
                              'title': title,
                              'message': message,
                              'type': 'general',
                              'is_read': false,
                              'sender_type': 'landlord',
                              'sender_name': widget.landlord.fullName,
                            });

                        if (!mounted || !dialogContext.mounted) return;

                        Navigator.pop(dialogContext);

                        setState(() => _creating = false);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notification sent to everyone in the apartment.',
                            ),
                          ),
                        );

                        await _loadNotifications();
                      } catch (e) {
                        if (!mounted) return;

                        setState(() => _creating = false);

                        debugPrint('LANDLORD NOTIFICATION CREATE ERROR: $e');

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not create notification: $e'),
                          ),
                        );
                      }
                    },
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    messageController.dispose();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return '';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _notificationCard(Map<String, dynamic> notification) {
    final title = notification['title']?.toString() ?? 'Notification';

    final message = notification['message']?.toString() ?? '';

    final senderType = notification['sender_type']?.toString() ?? '';

    final senderName = notification['sender_name']?.toString() ?? '';

    final isLandlord = senderType == 'landlord';

    final sender = senderName.isNotEmpty
        ? senderName
        : isLandlord
        ? 'Landlord'
        : 'Tenant';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Icon(
            isLandlord ? Icons.campaign_outlined : Icons.person_outline,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 6),
              Text(
                '$sender • ${_formatDate(notification['created_at'])}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _createNotification,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              widget.landlord.propertyName.isNotEmpty
                  ? widget.landlord.propertyName
                  : 'Apartment Notifications',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Communicate important updates with everyone in your apartment.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.campaign_outlined)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Apartment communication',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Notifications created by landlords and tenants are shared with members of this apartment.',
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
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(35),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_notifications.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.notifications_none_outlined,
                        size: 55,
                        color: Colors.grey,
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
                        'Create a notification to communicate an important update.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._notifications.map(_notificationCard),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
