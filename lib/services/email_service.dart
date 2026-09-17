import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<void> send({
    required String to,
    required String subject,
    required String html,
  }) async {
    final response = await _supabase.functions.invoke(
      'send-email',
      body: {'to': to, 'subject': subject, 'html': html},
    );

    if (response.data is Map && response.data['success'] != true) {
      throw Exception(
        response.data['error']?.toString() ?? 'Email sending failed.',
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
      html: _brandedEmail(
        title: 'Welcome to JUMAA',
        content:
            '''
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
  ''',
      ),
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
      html: _brandedEmail(
        title: 'Booking Request Received',
        content:
            '''
    <p>Hello <strong>${_escape(applicantName)}</strong>,</p>

    <p>
      We received your room request for
      <strong>${_escape(propertyName)}</strong>.
    </p>

    <p>
      Your request is currently
      <strong>pending</strong>.
    </p>

    <p>
      The landlord will review your request and you will receive
      another email when the status changes.
    </p>
  ''',
      ),
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
      html: _brandedEmail(
        title: title,
        content:
            '''
    <p>Hello <strong>${_escape(applicantName)}</strong>,</p>

    <p>$message</p>

    <p>
      Please open JUMAA to view the latest status of your request.
    </p>
  ''',
      ),
    );
  }

  static const String _logoUrl =
      'https://pdezijwjfqyulkkuhoun.supabase.co/storage/v1/object/public/email-assets/JUMAA.jpeg';

  static String _brandedEmail({
    required String title,
    required String content,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>JUMAA</title>
</head>
<body style="margin:0;padding:0;background:#f4f7f5;font-family:Arial,Helvetica,sans-serif;color:#1f2937;">
  <div style="width:100%;padding:32px 12px;box-sizing:border-box;">
    <div style="max-width:620px;margin:0 auto;background:#ffffff;border-radius:18px;overflow:hidden;box-shadow:0 4px 18px rgba(0,0,0,0.08);">

      <div style="background:#0B3D2E;padding:28px 24px;text-align:center;">
        <img
          src="$_logoUrl"
          alt="JUMAA"
          width="82"
          height="82"
          style="display:block;margin:0 auto 14px;width:82px;height:82px;border-radius:18px;object-fit:cover;background:#ffffff;"
        >
        <div style="font-size:25px;font-weight:700;color:#ffffff;letter-spacing:1px;">
          JUMAA
        </div>
        <div style="font-size:13px;color:#d7ebe3;margin-top:5px;">
          Join - Unite - Move - Access - Anywhere
        </div>
      </div>

      <div style="padding:32px 30px;">
        <h1 style="margin:0 0 22px;color:#0B3D2E;font-size:25px;line-height:1.3;">
          $title
        </h1>

        $content
      </div>

      <div style="border-top:1px solid #e5e7eb;padding:22px 24px;text-align:center;background:#fafcfb;">
        <div style="font-weight:700;color:#0B3D2E;font-size:15px;">
          JUMAA
        </div>
        <div style="font-size:12px;color:#6b7280;margin-top:6px;">
          Join - Unite - Move - Access - Anywhere
        </div>
        <div style="font-size:11px;color:#9ca3af;margin-top:12px;">
          This is an automated email from JUMAA.
        </div>
      </div>

    </div>
  </div>
</body>
</html>
''';
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
