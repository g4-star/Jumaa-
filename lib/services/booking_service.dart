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
    final response = await _supabase
        .from('booking_requests')
        .insert({
          'property_id': propertyId,
          'unit_id': unitId,
          'applicant_name': fullName.trim(),
          'applicant_email': email.trim(),
          'applicant_phone': phone.trim(),
          'additional_notes': message.trim(),
          'status': 'pending',
        })
        .select()
        .single();

    final booking = Map<String, dynamic>.from(response);

    // Get the property name for the booking confirmation email.
    final propertyResponse = await _supabase
        .from('properties')
        .select('name')
        .eq('id', propertyId)
        .single();

    final propertyName =
        propertyResponse['name']?.toString().trim() ?? 'the property';

    // Send confirmation email to the applicant.
    await EmailService.sendBookingReceived(
      applicantEmail: email.trim(),
      applicantName: fullName.trim(),
      propertyName: propertyName,
    );

    return booking;
  }

  Future<List<Map<String, dynamic>>> getMyBookings(String userId) async {
    // Public applicants currently do not need a tenant account.
    // This method is retained for compatibility with the application.
    final response = await _supabase
        .from('booking_requests')
        .select()
        .eq('applicant_email', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> cancelBooking(String bookingId) async {
    await _supabase
        .from('booking_requests')
        .update({'status': 'cancelled'})
        .eq('id', bookingId);
  }
}
