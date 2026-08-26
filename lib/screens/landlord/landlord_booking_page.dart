import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/landlord.dart';
import '../../services/email_service.dart';

class LandlordBookingPage extends StatefulWidget {
  final Landlord landlord;

  const LandlordBookingPage({super.key, required this.landlord});

  @override
  State<LandlordBookingPage> createState() => _LandlordBookingPageState();
}

class _LandlordBookingPageState extends State<LandlordBookingPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _bookings = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    debugPrint('LANDLORD BOOKINGS PAGE: INIT STATE REACHED');
    debugPrint('LANDLORD BOOKINGS PAGE: landlord=${widget.landlord.fullName}');

    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;

      debugPrint('LANDLORD BOOKINGS DEBUG: auth userId=$userId');
      debugPrint(
        'LANDLORD BOOKINGS DEBUG: auth email=${_supabase.auth.currentUser?.email}',
      );

      if (userId == null) {
        throw Exception('You must be logged in to view bookings.');
      }

      /*
       * We first get the landlord's properties.
       *
       * The landlord model does not necessarily expose the Supabase
       * property UUID, so we identify properties through owner_id.
       */
      final properties = await _supabase
          .from('properties')
          .select('id, name')
          .eq('landlord_id', userId);

      debugPrint(
        'LANDLORD BOOKINGS DEBUG: properties count=${properties.length}',
      );
      debugPrint('LANDLORD BOOKINGS DEBUG: properties=$properties');

      if (properties.isEmpty) {
        if (!mounted) return;

        setState(() {
          _bookings = [];
          _loading = false;
        });

        return;
      }

      final propertyIds = properties
          .map((row) => row['id'].toString())
          .toList();

      debugPrint('LANDLORD BOOKINGS DEBUG: propertyIds=$propertyIds');

      final response = await _supabase
          .from('booking_requests')
          .select('''
            id,
            property_id,
            unit_id,
            applicant_name,
            applicant_email,
            applicant_phone,
            additional_notes,
            status,
            created_at,
            updated_at
          ''')
          .inFilter('property_id', propertyIds)
          .order('created_at', ascending: false);

      debugPrint(
        'LANDLORD BOOKINGS DEBUG: booking_requests count=${response.length}',
      );
      debugPrint(
        'LANDLORD BOOKINGS DEBUG: booking_requests response=$response',
      );

      if (!mounted) return;

      setState(() {
        _bookings = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    try {
      // Find the booking locally so we have all applicant information.
      final booking = _bookings.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['id']?.toString() == bookingId,
        orElse: () => null,
      );

      if (booking == null) {
        throw Exception('Booking request could not be found.');
      }

      final applicantName = booking['applicant_name']?.toString().trim() ?? '';

      final applicantEmail =
          booking['applicant_email']?.toString().trim().toLowerCase() ?? '';

      final applicantPhone =
          booking['applicant_phone']?.toString().trim() ?? '';

      final propertyId = booking['property_id']?.toString().trim() ?? '';

      final unitId = booking['unit_id']?.toString().trim() ?? '';

      if (applicantName.isEmpty ||
          applicantEmail.isEmpty ||
          applicantPhone.isEmpty ||
          propertyId.isEmpty ||
          unitId.isEmpty) {
        throw Exception(
          'The booking is missing applicant, property or unit information.',
        );
      }

      // Get the property name for notification emails.
      var propertyName = 'your requested property';

      final property = await _supabase
          .from('properties')
          .select('name')
          .eq('id', propertyId)
          .maybeSingle();

      if (property != null &&
          property['name']?.toString().trim().isNotEmpty == true) {
        propertyName = property['name'].toString().trim();
      }

      // ==========================================================
      // APPROVAL
      // ==========================================================
      if (status == 'approved') {
        // ----------------------------------------------------------
        // 1. Check whether this booking already created a tenant.
        // ----------------------------------------------------------
        final existingBookingTenant = await _supabase
            .from('tenants')
            .select('id, auth_user_id, full_name, email, phone, account_status')
            .eq('booking_request_id', bookingId)
            .maybeSingle();

        String tenantId;

        if (existingBookingTenant != null) {
          tenantId = existingBookingTenant['id']?.toString() ?? '';

          if (tenantId.isEmpty) {
            throw Exception(
              'An existing tenant record was found for this booking, '
              'but its tenant ID is missing.',
            );
          }

          // If this booking already has a fully linked Auth account,
          // do not create another account.
          final existingAuthUserId =
              existingBookingTenant['auth_user_id']?.toString() ?? '';

          if (existingAuthUserId.isNotEmpty) {
            // ------------------------------------------------------
            // IMPORTANT:
            // The tenant record may already exist because the
            // tenant account was created previously. In that case,
            // approval must still synchronize the tenant's
            // property_id and unit_id from this booking.
            // ------------------------------------------------------
            final updatedTenant = await _supabase
                .from('tenants')
                .update({
                  'property_id': propertyId,
                  'unit_id': unitId,
                  'account_status': 'active',
                })
                .eq('id', tenantId)
                .select('id, property_id, unit_id, account_status')
                .maybeSingle();

            debugPrint(
              'LANDLORD BOOKINGS: existing tenant assignment synced: '
              '$updatedTenant',
            );

            if (updatedTenant == null) {
              throw Exception(
                'Tenant account exists, but the tenant could not be '
                'assigned to the approved property and unit.',
              );
            }

            await _supabase
                .from('booking_requests')
                .update({'status': 'approved'})
                .eq('id', bookingId);

            // Synchronize the booked unit with the approved booking.
            if (unitId.isNotEmpty) {
              final updatedUnits = await _supabase
                  .from('units')
                  .update({'status': 'occupied'})
                  .eq('id', unitId)
                  .select('id, status');

              debugPrint(
                'LANDLORD BOOKINGS: occupancy sync result=$updatedUnits',
              );

              if (updatedUnits.isEmpty) {
                debugPrint(
                  'LANDLORD BOOKINGS WARNING: unit $unitId was not updated.',
                );
              }
            } else {
              debugPrint(
                'LANDLORD BOOKINGS WARNING: approved booking has empty unit_id.',
              );
            }

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This booking is already approved and the tenant account already exists.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );

            await _loadBookings();
            return;
          }
        } else {
          // --------------------------------------------------------
          // 2. Make sure another tenant is not occupying this unit.
          // --------------------------------------------------------
          final existingUnitTenant = await _supabase
              .from('tenants')
              .select(
                'id, booking_request_id, full_name, email, account_status',
              )
              .eq('unit_id', unitId)
              .maybeSingle();

          if (existingUnitTenant != null) {
            final otherBookingId =
                existingUnitTenant['booking_request_id']?.toString() ?? '';

            if (otherBookingId.isEmpty || otherBookingId != bookingId) {
              throw Exception('This unit already has a tenant assigned to it.');
            }
          }

          // --------------------------------------------------------
          // 3. Create the tenant record from the approved booking.
          // --------------------------------------------------------
          final tenantResponse = await _supabase
              .from('tenants')
              .insert({
                'booking_request_id': bookingId,
                'property_id': propertyId,
                'unit_id': unitId,
                'full_name': applicantName,
                'email': applicantEmail,
                'phone': applicantPhone,
                'account_status': 'active',
              })
              .select()
              .single();

          tenantId = tenantResponse['id']?.toString() ?? '';

          if (tenantId.isEmpty) {
            throw Exception(
              'Tenant was created but no tenant ID was returned.',
            );
          }
        }

        // ----------------------------------------------------------
        // 4. Create Supabase Auth account + profile + invitation.
        // ----------------------------------------------------------
        final accountResponse = await _supabase.functions.invoke(
          'create-tenant-account',
          body: {
            'tenant_id': tenantId,
            'full_name': applicantName,
            'email': applicantEmail,
            'phone': applicantPhone,
            'apartment': unitId,
          },
        );

        final accountData = accountResponse.data;

        if (accountResponse.status != 200) {
          String accountError = 'Tenant account could not be created.';

          if (accountData is Map && accountData['error'] != null) {
            accountError = accountData['error'].toString();
          }

          throw Exception(accountError);
        }

        if (accountData is! Map || accountData['success'] != true) {
          throw Exception(
            accountData is Map && accountData['error'] != null
                ? accountData['error'].toString()
                : 'Tenant account could not be created.',
          );
        }

        if (accountData['email_sent'] == false) {
          throw Exception(
            'Tenant account was created, but the invitation email could not be sent.',
          );
        }

        // ----------------------------------------------------------
        // 5. Mark the booking as approved.
        // ----------------------------------------------------------
        await _supabase
            .from('booking_requests')
            .update({'status': 'approved'})
            .eq('id', bookingId);

        // ----------------------------------------------------------
        // 6. Synchronize the booked unit.
        // ----------------------------------------------------------
        // booking_requests.unit_id points directly to units.id.
        // An approved booking means this unit is now occupied.
        if (unitId.isNotEmpty) {
          final updatedUnits = await _supabase
              .from('units')
              .update({'status': 'occupied'})
              .eq('id', unitId)
              .select('id, status');

          debugPrint(
            'LANDLORD BOOKINGS: occupancy sync result=$updatedUnits',
          );

          if (updatedUnits.isEmpty) {
            debugPrint(
              'LANDLORD BOOKINGS WARNING: unit $unitId was not updated.',
            );
          }
        } else {
          debugPrint(
            'LANDLORD BOOKINGS WARNING: approved booking has empty unit_id.',
          );
        }

        // ----------------------------------------------------------
        // 7. Send the booking approval notification.
        // ----------------------------------------------------------
        String? emailError;

        try {
          await EmailService.sendBookingDecision(
            applicantEmail: applicantEmail,
            applicantName: applicantName,
            propertyName: propertyName,
            approved: true,
          );
        } catch (e) {
          emailError = e.toString();
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              emailError == null
                  ? 'Booking approved. Tenant account created and invitation sent.'
                  : 'Booking approved. Tenant account created, but booking notification failed.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        await _loadBookings();
        return;
      }

      // ==========================================================
      // REJECTION
      // ==========================================================
      if (status == 'rejected') {
        await _supabase
            .from('booking_requests')
            .update({'status': 'rejected'})
            .eq('id', bookingId);

        String? emailError;

        if (applicantEmail.isNotEmpty) {
          try {
            await EmailService.sendBookingDecision(
              applicantEmail: applicantEmail,
              applicantName: applicantName,
              propertyName: propertyName,
              approved: false,
            );
          } catch (e) {
            emailError = e.toString();
          }
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              emailError == null
                  ? 'Booking rejected.'
                  : 'Booking rejected. Email notification failed.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        await _loadBookings();
        return;
      }

      throw Exception('Unsupported booking status: $status');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update booking: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showBookingDetails(Map<String, dynamic> booking) async {
    final status = booking['status']?.toString() ?? 'pending';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Booking Request',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                  ),

                  const SizedBox(height: 18),

                  _detailRow(
                    Icons.person_outline,
                    'Applicant',
                    booking['applicant_name']?.toString() ?? 'Not provided',
                  ),

                  _detailRow(
                    Icons.email_outlined,
                    'Email',
                    booking['applicant_email']?.toString() ?? 'Not provided',
                  ),

                  _detailRow(
                    Icons.phone_outlined,
                    'Phone',
                    booking['applicant_phone']?.toString() ?? 'Not provided',
                  ),

                  _detailRow(
                    Icons.home_outlined,
                    'Unit',
                    booking['unit_id']?.toString() ?? 'Not provided',
                  ),

                  _detailRow(
                    Icons.info_outline,
                    'Status',
                    status.toUpperCase(),
                  ),

                  if ((booking['additional_notes']?.toString() ?? '')
                      .trim()
                      .isNotEmpty)
                    _detailRow(
                      Icons.message_outlined,
                      'Message',
                      booking['additional_notes'].toString(),
                    ),

                  if (booking['created_at'] != null)
                    _detailRow(
                      Icons.access_time,
                      'Submitted',
                      _formatDate(booking['created_at'].toString()),
                    ),

                  const SizedBox(height: 20),

                  if (status.toLowerCase() == 'pending')
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _updateBookingStatus(
                                booking['id'].toString(),
                                'rejected',
                              );
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('REJECT'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _updateBookingStatus(
                                booking['id'].toString(),
                                'approved',
                              );
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('APPROVE'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final name = booking['applicant_name']?.toString().trim();

    final displayName = name == null || name.isEmpty
        ? 'Unknown applicant'
        : name;

    final status = booking['status']?.toString() ?? 'pending';

    final message = booking['additional_notes']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showBookingDetails(booking),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          booking['applicant_email']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(status),
                ],
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 17),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      booking['applicant_phone']?.toString() ?? 'No phone',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.home_outlined, size: 17),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Unit: ${booking['unit_id']?.toString() ?? 'Unknown'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),

              if (message.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],

              const SizedBox(height: 12),

              Row(
                children: [
                  if (booking['created_at'] != null)
                    Expanded(
                      child: Text(
                        _formatDate(booking['created_at'].toString()),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ),

                  if (status.toLowerCase() == 'pending') ...[
                    TextButton(
                      onPressed: () => _updateBookingStatus(
                        booking['id'].toString(),
                        'rejected',
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: () => _updateBookingStatus(
                        booking['id'].toString(),
                        'approved',
                      ),
                      child: const Text('Approve'),
                    ),
                  ] else
                    const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apartmentName = widget.landlord.propertyName.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bookings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadBookings,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBookings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            Text(
              apartmentName.isNotEmpty ? apartmentName : 'Your Apartment',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              'Manage booking requests from prospective tenants.',
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 20),

            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load bookings',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadBookings,
                        icon: const Icon(Icons.refresh),
                        label: const Text('TRY AGAIN'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_bookings.isEmpty)
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 55,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No booking requests yet',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'New booking requests from users will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Text(
                '${_bookings.length} booking request${_bookings.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ..._bookings.map(_bookingCard),
            ],
          ],
        ),
      ),
    );
  }
}
