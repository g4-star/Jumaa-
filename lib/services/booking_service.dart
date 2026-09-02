import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'email_service.dart';

class BookingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> createBooking({
    required String propertyId,
    required String unitId,
    required String fullName,
    required String email,
    required String phone,
    String message = '',
  }) async {
    debugPrint('BOOKING DEBUG 1: createBooking() started');
    debugPrint('BOOKING DEBUG propertyId=$propertyId');
    debugPrint('BOOKING DEBUG unitId=$unitId');
    debugPrint('BOOKING DEBUG name=$fullName');
    debugPrint('BOOKING DEBUG email=$email');

    final applicantName = fullName.trim();
    final applicantEmail = email.trim().toLowerCase();
    final applicantPhone = phone.trim();
    final additionalNotes = message.trim();

    if (applicantName.isEmpty) {
      throw Exception('Please enter your full name.');
    }

    if (applicantEmail.isEmpty) {
      throw Exception('Please enter your email address.');
    }

    if (applicantPhone.isEmpty) {
      throw Exception('Please enter your phone number.');
    }

    if (propertyId.trim().isEmpty) {
      throw Exception('Property information is missing.');
    }

    if (unitId.trim().isEmpty) {
      throw Exception('Unit information is missing.');
    }

    debugPrint(
      'BOOKING DEBUG 2: inserting into booking_requests...',
    );

    final response = await _supabase.rpc(
      'create_booking_request',
      params: {
        'p_property_id': propertyId,
        'p_unit_id': unitId,
        'p_applicant_name': applicantName,
        'p_applicant_email': applicantEmail,
        'p_applicant_phone': applicantPhone,
        'p_additional_notes': additionalNotes,
      },
    );

    if (response == null) {
      throw Exception('Booking request could not be created.');
    }

    final booking = Map<String, dynamic>.from(response);

    debugPrint(
      'BOOKING DEBUG 3: booking request inserted successfully',
    );

    debugPrint(
      'BOOKING DEBUG booking_request_id=${booking['id']}',
    );

    // Get the property name for the confirmation email.
    String propertyName = 'the property';

    try {
      debugPrint('BOOKING DEBUG 4: loading property name...');

      final propertyResponse = await _supabase
          .from('properties')
          .select('name')
          .eq('id', propertyId)
          .maybeSingle();

      if (propertyResponse != null) {
        final name =
            propertyResponse['name']?.toString().trim() ?? '';

        if (name.isNotEmpty) {
          propertyName = name;
        }
      }

      debugPrint(
        'BOOKING DEBUG 5: property name=$propertyName',
      );
    } catch (e) {
      debugPrint(
        'BOOKING DEBUG property lookup failed: $e',
      );

      // The booking already exists, so don't fail the booking
      // merely because the property-name lookup failed.
    }

    // Send confirmation email to the applicant.
    //
    // IMPORTANT:
    // The booking has already been successfully stored.
    // Therefore an email failure must NOT delete or invalidate
    // the booking request.
    debugPrint(
      'BOOKING DEBUG 6: sending confirmation email...',
    );

    try {
      await EmailService.sendBookingReceived(
        applicantEmail: applicantEmail,
        applicantName: applicantName,
        propertyName: propertyName,
      );

      debugPrint(
        'BOOKING DEBUG 7: confirmation email completed',
      );
    } catch (e) {
      debugPrint(
        'BOOKING DEBUG email failed: $e',
      );

      debugPrint(
        'BOOKING DEBUG booking request was already created successfully',
      );
    }

    return booking;
  }

  Future<List<Map<String, dynamic>>> getMyBookings(
    String email,
  ) async {
    final response = await _supabase
        .from('booking_requests')
        .select()
        .eq(
          'applicant_email',
          email.trim().toLowerCase(),
        )
        .order(
          'created_at',
          ascending: false,
        );

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> cancelBooking(String bookingId) async {
    await _supabase
        .from('booking_requests')
        .update({
          'status': 'cancelled',
        })
        .eq('id', bookingId);
  }
}
