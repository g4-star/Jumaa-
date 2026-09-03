import 'dart:async';

import 'package:flutter/material.dart';

import '../../main.dart' show OpenNestStore;

class OwnerNotificationsPage extends StatefulWidget {
  const OwnerNotificationsPage({super.key});

  @override
  State<OwnerNotificationsPage> createState() => _OwnerNotificationsPageState();
}

class _OwnerNotificationsPageState extends State<OwnerNotificationsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final user = OpenNestStore.supabase.auth.currentUser;

      if (user == null) {
        throw Exception('You are not signed in.');
      }

      final response = await OpenNestStore.supabase
          .from('owner_notifications')
          .select('*, owner_requests(*)')
          .eq('owner_id', user.id)
          .order('created_at', ascending: false);

      final notifications = (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('OWNER NOTIFICATIONS LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final id = notification['id']?.toString();

    if (id == null || id.isEmpty) return;

    try {
      if (notification['is_read'] != true) {
        await OpenNestStore.supabase
            .from('owner_notifications')
            .update({'is_read': true})
            .eq('id', id);

        notification['is_read'] = true;
      }
    } catch (e) {
      debugPrint('OWNER NOTIFICATION MARK READ ERROR: $e');
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            OwnerNotificationDetailsPage(notification: notification),
      ),
    );

    await _loadNotifications();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    final local = date.toLocal();

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications
        .where((notification) => notification['is_read'] != true)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '$unreadCount unread',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 54),
              const SizedBox(height: 14),
              const Text(
                'Unable to load notifications',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                  });
                  _loadNotifications();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 72,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Notifications from the JUMAA platform owner '
                        'will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final notification = _notifications[index];

          final title =
              notification['title']?.toString() ?? 'JUMAA Notification';

          final message = notification['message']?.toString() ?? '';

          final type =
              notification['notification_type']?.toString() ?? 'general';

          final isRead = notification['is_read'] == true;

          return Card(
            elevation: isRead ? 0 : 2,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                child: Icon(
                  isRead
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_active_rounded,
                ),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(
                      '${type.toUpperCase()} • ${_formatDate(notification['created_at'])}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: isRead
                  ? const Icon(Icons.chevron_right)
                  : Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                    ),
              onTap: () => _openNotification(notification),
            ),
          );
        },
      ),
    );
  }
}

class OwnerNotificationDetailsPage extends StatelessWidget {
  const OwnerNotificationDetailsPage({super.key, required this.notification});

  final Map<String, dynamic> notification;

  String _formatDate(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    return '${date.toLocal()}'.split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    final title = notification['title']?.toString() ?? 'JUMAA Notification';

    final message = notification['message']?.toString() ?? '';

    final type = notification['notification_type']?.toString() ?? 'general';

    final request = notification['owner_requests'];

    final requestData = request is Map
        ? Map<String, dynamic>.from(request)
        : null;

    final subject = requestData?['subject']?.toString();

    final requestMessage = requestData?['message']?.toString();

    final requestStatus = requestData?['status']?.toString();

    final rejectionReason = requestData?['rejection_reason']?.toString();

    final requestedUntil = requestData?['requested_until']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 34,
            child: Icon(Icons.notifications_active_rounded, size: 32),
          ),
          const SizedBox(height: 18),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            '${type.toUpperCase()} • ${_formatDate(notification['created_at'])}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),

          const SizedBox(height: 28),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                message,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ),

          if (subject != null && subject.isNotEmpty) ...[
            const SizedBox(height: 18),
            _detailCard('Your Request', subject),
          ],

          if (requestMessage != null && requestMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            _detailCard('Request Message', requestMessage),
          ],

          if (requestStatus != null && requestStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            _detailCard('Status', requestStatus.toUpperCase()),
          ],

          if (requestedUntil != null && requestedUntil.isNotEmpty) ...[
            const SizedBox(height: 12),
            _detailCard('Requested Until', requestedUntil),
          ],

          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            _detailCard('Reason', rejectionReason),
          ],
        ],
      ),
    );
  }

  Widget _detailCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 7),
            Text(value, style: const TextStyle(fontSize: 15, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
