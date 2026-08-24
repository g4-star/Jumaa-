import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  static final SupabaseClient _supabase =
      Supabase.instance.client;

  static Future<void> send({
    required String to,
    required String subject,
    required String html,
  }) async {
    final response = await _supabase.functions.invoke(
      'send-email',
      body: {
        'to': to,
        'subject': subject,
        'html': html,
      },
    );

    if (response.data is Map &&
        response.data['success'] != true) {
      throw Exception(
        response.data['error']?.toString() ??
            'Email sending failed.',
      );
    }
  }

  static Future<void> sendOwnerWelcome({
    required String email,
    required String ownerName,
    required String propertyName,
  }) async {
    await send(
      to: email,
      subject: 'Welcome to JUMAA',
      html: '''
<!DOCTYPE html>
<html>
<body style="font-family:Arial,sans-serif;background:#f7f9f8;padding:30px;">
  <div style="max-width:600px;margin:auto;background:white;padding:30px;border-radius:16px;">
    <h1 style="color:#0B3D2E;">Welcome to JUMAA</h1>

    <p>Hello <strong>${_escape(ownerName)}</strong>,</p>

    <p>Your JUMAA owner account has been created successfully.</p>

    <p>
      Your property
      <strong>${_escape(propertyName)}</strong>
      has also been registered.
    </p>

    <p>You can now continue setting up your property and managing your apartments.</p>

    <p style="color:#666;">
      Thank you for choosing JUMAA.
    </p>
  </div>
</body>
</html>
''',
    );
  }

  static Future<void> sendBookingReceived({
    required String applicantEmail,
    required String applicantName,
    required String propertyName,
  }) async {
    await send(
      to: applicantEmail,
      subject: 'JUMAA booking request received',
      html: '''
<!DOCTYPE html>
<html>
<body style="font-family:Arial,sans-serif;background:#f7f9f8;padding:30px;">
  <div style="max-width:600px;margin:auto;background:white;padding:30px;border-radius:16px;">
    <h1 style="color:#0B3D2E;">Booking Request Received</h1>

    <p>Hello <strong>${_escape(applicantName)}</strong>,</p>

    <p>
      We received your room request for
      <strong>${_escape(propertyName)}</strong>.
    </p>

    <p>
      Your request is currently
      <strong>pending</strong>.
    </p>

    <p>The landlord will review your request and you will receive another email when the status changes.</p>

    <p>— JUMAA</p>
  </div>
</body>
</html>
''',
    );
  }

  static Future<void> sendBookingDecision({
    required String applicantEmail,
    required String applicantName,
    required String propertyName,
    required bool approved,
  }) async {
    final subject = approved
        ? 'Your JUMAA booking request was approved'
        : 'Your JUMAA booking request was rejected';

    final title = approved
        ? 'Booking Request Approved'
        : 'Booking Request Update';

    final message = approved
        ? '''
Your request for <strong>${_escape(propertyName)}</strong>
has been <strong>approved</strong>.
'''
        : '''
Your request for <strong>${_escape(propertyName)}</strong>
has been <strong>rejected</strong>.
''';

    await send(
      to: applicantEmail,
      subject: subject,
      html: '''
<!DOCTYPE html>
<html>
<body style="font-family:Arial,sans-serif;background:#f7f9f8;padding:30px;">
  <div style="max-width:600px;margin:auto;background:white;padding:30px;border-radius:16px;">
    <h1 style="color:#0B3D2E;">$title</h1>

    <p>Hello <strong>${_escape(applicantName)}</strong>,</p>

    <p>$message</p>

    <p>
      Please open JUMAA to view the latest status of your request.
    </p>

    <p>— JUMAA</p>
  </div>
</body>
</html>
''',
    );
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }
}
