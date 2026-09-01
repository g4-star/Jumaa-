import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/landlord.dart';

class LandlordTenantsPage extends StatefulWidget {
  final Landlord landlord;

  const LandlordTenantsPage({super.key, required this.landlord});

  @override
  State<LandlordTenantsPage> createState() => _LandlordTenantsPageState();
}

class _LandlordTenantsPageState extends State<LandlordTenantsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _tenants = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final propertyId = widget.landlord.propertyId.trim();

    debugPrint(
      'LANDLORD TENANTS: loading tenants for '
      'landlord=${widget.landlord.fullName} '
      'propertyId=$propertyId '
      'property=${widget.landlord.propertyName}',
    );

    if (propertyId.isEmpty) {
      debugPrint('LANDLORD TENANTS ERROR: landlord propertyId is empty');

      if (!mounted) return;

      setState(() {
        _tenants = [];
        _loading = false;
        _error = 'This landlord is not assigned to a property yet.';
      });

      return;
    }

    try {
      final response = await _supabase
          .from('tenants')
          .select(
            'id, booking_request_id, property_id, unit_id, '
            'full_name, email, phone, account_status, move_in_date, '
            'created_at, units(unit_number, unit_type)',
          )
          .eq('property_id', propertyId)
          .order('created_at', ascending: false);

      debugPrint(
        'LANDLORD TENANTS: Supabase returned '
        '${response.length} tenants',
      );

      final tenants = <Map<String, dynamic>>[];

      for (final row in response) {
        debugPrint(
          'LANDLORD TENANT: '
          'id=${row['id']} '
          'name=${row['full_name']} '
          'unitId=${row['unit_id']} '
          'status=${row['account_status']}',
        );

        tenants.add(Map<String, dynamic>.from(row));
      }

      if (!mounted) return;

      setState(() {
        _tenants = tenants;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('LANDLORD TENANTS ERROR: $e');
      debugPrint('LANDLORD TENANTS STACK: $stackTrace');

      if (!mounted) return;

      setState(() {
        _tenants = [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tenants',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh tenants',
            onPressed: _loading ? null : _loadTenants,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorState()
          : _tenants.isEmpty
          ? _emptyState()
          : RefreshIndicator(
              onRefresh: _loadTenants,
              child: ListView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: _tenants.length,
                itemBuilder: (context, index) {
                  return _tenantCard(context, _tenants[index]);
                },
              ),
            ),
    );
  }

  Widget _tenantCard(BuildContext context, Map<String, dynamic> tenant) {
    final name = tenant['full_name']?.toString().trim().isNotEmpty == true
        ? tenant['full_name'].toString().trim()
        : 'Tenant';

    final email = tenant['email']?.toString() ?? '';
    final phone = tenant['phone']?.toString() ?? '';

    final unit = tenant['units'];

    String unitNumber = 'Unknown';

    if (unit is Map<String, dynamic>) {
      final number = unit['unit_number']?.toString() ?? '';
      if (number.trim().isNotEmpty) {
        unitNumber = number;
      }
    }

    final status = tenant['account_status']?.toString() ?? 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(child: Text(name.substring(0, 1).toUpperCase())),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Unit $unitNumber'),
              if (phone.isNotEmpty) Text(phone),
              if (email.isNotEmpty) Text(email),
            ],
          ),
        ),
        trailing: _statusChip(status),
        onTap: () => _showTenantDetails(context, tenant, unitNumber),
      ),
    );
  }

  Widget _statusChip(String status) {
    final label = status.isEmpty
        ? 'Active'
        : status[0].toUpperCase() + status.substring(1);

    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _emptyState() {
    return RefreshIndicator(
      onRefresh: _loadTenants,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.28),
          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 65,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 15),
                const Text(
                  'No tenants yet',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 7),
                Text(
                  'No tenants are currently assigned to this property.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _loadTenants,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text(
              'Could not load tenants',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _error ?? 'Unknown database error.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadTenants,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTenantDetails(
    BuildContext context,
    Map<String, dynamic> tenant,
    String unitNumber,
  ) {
    final name = tenant['full_name']?.toString() ?? 'Tenant';
    final email = tenant['email']?.toString() ?? '';
    final phone = tenant['phone']?.toString() ?? '';
    final status = tenant['account_status']?.toString() ?? 'active';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                _detailRow(Icons.apartment, 'Unit', unitNumber),
                if (phone.isNotEmpty) _detailRow(Icons.phone, 'Phone', phone),
                if (email.isNotEmpty)
                  _detailRow(Icons.email_outlined, 'Email', email),
                _detailRow(Icons.verified_user_outlined, 'Account', status),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
