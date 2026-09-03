import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactJumaaOwnerPage extends StatefulWidget {
  const ContactJumaaOwnerPage({super.key});

  @override
  State<ContactJumaaOwnerPage> createState() => _ContactJumaaOwnerPageState();
}

class _ContactJumaaOwnerPageState extends State<ContactJumaaOwnerPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String _requestType = 'general';
  DateTime? _requestedUntil;
  bool _sending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: _requestedUntil ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (date != null) {
      setState(() => _requestedUntil = date);
    }
  }

  Future<void> _sendRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;

    if (user == null) {
      _message('Please log in again.');
      return;
    }

    setState(() => _sending = true);

    try {
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['role'] != 'owner') {
        throw Exception('Only apartment owners can send requests.');
      }

      final data = <String, dynamic>{
        'owner_id': user.id,
        'request_type': _requestType,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
      };

      if (_requestedUntil != null) {
        data['requested_until'] = _requestedUntil!
            .toIso8601String()
            .split('T')
            .first;
      }

      await _supabase.from('owner_requests').insert(data);

      if (!mounted) return;

      _message('Request sent successfully.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      _message('Could not send request. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final needsDate =
        _requestType == 'subscription' ||
        _requestType == 'trial' ||
        _requestType == 'suspension';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contact JUMAA Owner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.support_agent_rounded, size: 60),
            const SizedBox(height: 12),
            const Text(
              'Send a Request',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Send your request directly to the JUMAA platform owner.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 28),

            DropdownButtonFormField<String>(
              initialValue: _requestType,
              decoration: const InputDecoration(
                labelText: 'Request Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'general',
                  child: Text('General Request'),
                ),
                DropdownMenuItem(
                  value: 'subscription',
                  child: Text('Subscription / Payment'),
                ),
                DropdownMenuItem(
                  value: 'trial',
                  child: Text('Free Trial Request'),
                ),
                DropdownMenuItem(
                  value: 'suspension',
                  child: Text('Account Suspension Request'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: _sending
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _requestType = value;

                        if (value == 'general' || value == 'other') {
                          _requestedUntil = null;
                        }
                      });
                    },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'What is your request about?',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a subject.';
                }

                if (value.trim().length < 3) {
                  return 'Subject is too short.';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _messageController,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Explain your request to the JUMAA Owner...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your message.';
                }

                if (value.trim().length < 10) {
                  return 'Please provide more details.';
                }

                return null;
              },
            ),

            if (needsDate) ...[
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                leading: const Icon(Icons.calendar_month_rounded),
                title: const Text('Requested Until'),
                subtitle: Text(
                  _requestedUntil == null
                      ? 'Optional'
                      : '${_requestedUntil!.day.toString().padLeft(2, '0')}/'
                            '${_requestedUntil!.month.toString().padLeft(2, '0')}/'
                            '${_requestedUntil!.year}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _sending ? null : _pickDate,
              ),
            ],

            const SizedBox(height: 28),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _sending ? null : _sendRequest,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Sending...' : 'Send Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
