import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JumaaOwnerNotificationsPage extends StatefulWidget {
  const JumaaOwnerNotificationsPage({super.key});

  @override
  State<JumaaOwnerNotificationsPage> createState() =>
      _JumaaOwnerNotificationsPageState();
}

class _JumaaOwnerNotificationsPageState
    extends State<JumaaOwnerNotificationsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _supabase
          .from('owner_requests')
          .select('''
            id,
            owner_id,
            request_type,
            subject,
            message,
            status,
            rejection_reason,
            requested_until,
            reviewed_at,
            reviewed_by,
            created_at,
            updated_at
          ''')
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _requests = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('JUMAA OWNER NOTIFICATIONS: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Could not load owner requests.';
        _loading = false;
      });
    }
  }

  Future<void> _openRequest(Map<String, dynamic> request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _OwnerRequestDetailsPage(
          request: request,
          supabase: _supabase,
          onChanged: _loadRequests,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _requestIcon(String type) {
    switch (type.toLowerCase()) {
      case 'subscription':
      case 'subscription_postponement':
        return Icons.calendar_month_rounded;
      case 'free_trial':
        return Icons.card_giftcard_rounded;
      case 'suspension':
      case 'account_suspension':
        return Icons.lock_open_rounded;
      default:
        return Icons.mail_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _requests
        .where((r) => r['status'] == 'pending')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (pendingCount > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pendingCount pending',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadRequests, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 52,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Text(_error!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadRequests,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_requests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 70,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'Requests from apartment owners will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final request = _requests[index];

        final type = request['request_type']?.toString() ?? 'general';
        final subject = request['subject']?.toString() ?? 'Owner request';
        final message = request['message']?.toString() ?? '';
        final status = request['status']?.toString() ?? 'pending';

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openRequest(request),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _requestIcon(type),
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subject,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          type.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF7C3AED),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OwnerRequestDetailsPage extends StatefulWidget {
  final Map<String, dynamic> request;
  final SupabaseClient supabase;
  final Future<void> Function() onChanged;

  const _OwnerRequestDetailsPage({
    required this.request,
    required this.supabase,
    required this.onChanged,
  });

  @override
  State<_OwnerRequestDetailsPage> createState() =>
      _OwnerRequestDetailsPageState();
}

class _OwnerRequestDetailsPageState extends State<_OwnerRequestDetailsPage> {
  bool _working = false;

  String get _status =>
      widget.request['status']?.toString().toLowerCase() ?? 'pending';

  String get _requestId => widget.request['id'].toString();

  Future<void> _accept() async {
    if (_working || _status != 'pending') return;

    setState(() => _working = true);

    try {
      final user = widget.supabase.auth.currentUser;

      final updatedRequest = await widget.supabase
          .from('owner_requests')
          .update({
            'status': 'accepted',
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            'reviewed_by': user?.id,
          })
          .eq('id', _requestId)
          .eq('status', 'pending')
          .select('id')
          .maybeSingle();

      if (updatedRequest == null) {
        throw Exception(
          'This request has already been reviewed or could not be updated.',
        );
      }

      final notificationResponse = await widget.supabase.functions.invoke(
        'send-jumaa-notification',
        body: {'owner_request_id': _requestId, 'action': 'accepted'},
      );

      debugPrint(
        'OWNER REQUEST ACCEPTANCE NOTIFICATION: ${notificationResponse.data}',
      );

      await widget.onChanged();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request accepted.')));

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('ACCEPT OWNER REQUEST: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not accept request: $e')));
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _reject() async {
    if (_working || _status != 'pending') return;

    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Request'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
              hintText: 'Enter the reason...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a rejection reason.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _working = true);

    try {
      final user = widget.supabase.auth.currentUser;

      final updatedRequest = await widget.supabase
          .from('owner_requests')
          .update({
            'status': 'rejected',
            'rejection_reason': reason.trim(),
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            'reviewed_by': user?.id,
          })
          .eq('id', _requestId)
          .eq('status', 'pending')
          .select('id')
          .maybeSingle();

      if (updatedRequest == null) {
        throw Exception(
          'This request has already been reviewed or could not be updated.',
        );
      }

      final notificationResponse = await widget.supabase.functions.invoke(
        'send-jumaa-notification',
        body: {'owner_request_id': _requestId, 'action': 'rejected'},
      );

      debugPrint(
        'OWNER REQUEST REJECTION NOTIFICATION: ${notificationResponse.data}',
      );

      await widget.onChanged();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request rejected.')));

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('REJECT OWNER REQUEST: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not reject request: $e')));
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.request['subject']?.toString() ?? 'Owner request';

    final message = widget.request['message']?.toString() ?? '';

    final type = widget.request['request_type']?.toString() ?? 'general';

    final requestedUntil = widget.request['requested_until']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text(
          'Request',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _infoChip(type.replaceAll('_', ' ').toUpperCase()),
            const SizedBox(height: 24),
            const Text(
              'Request',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            if (requestedUntil != null && requestedUntil.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Requested Until',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                requestedUntil,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_status != 'pending') ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _status == 'accepted'
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _status == 'accepted'
                      ? 'This request has already been accepted.'
                      : 'This request has been rejected.\n\nReason: ${widget.request['rejection_reason'] ?? 'No reason provided.'}',
                  style: TextStyle(
                    color: _status == 'accepted'
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if (_status == 'pending') ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _working ? null : _reject,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _working ? null : _accept,
                      icon: _working
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('Accept'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7C3AED),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
