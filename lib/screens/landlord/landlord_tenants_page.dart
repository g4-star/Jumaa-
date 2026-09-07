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

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Unable to load tenants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadTenants,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            const Text(
              'No Tenants Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tenants assigned to this property will appear here.',
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
    );
  }

  Widget _tenantCard(BuildContext context, Map<String, dynamic> tenant) {
    final name = tenant['full_name']?.toString().trim().isNotEmpty == true
        ? tenant['full_name'].toString().trim()
        : 'Unknown Tenant';

    final unit = tenant['units'];
    final unitNumber = unit is Map
        ? unit['unit_number']?.toString() ?? 'N/A'
        : 'N/A';

    final phone = tenant['phone']?.toString() ?? '';
    final email = tenant['email']?.toString() ?? '';
    final status = tenant['account_status']?.toString() ?? 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Unit $unitNumber'),
            if (phone.isNotEmpty) Text(phone),
            if (email.isNotEmpty) Text(email),
            Text(
              'Status: $status',
              style: TextStyle(
                color: status.toLowerCase() == 'active'
                    ? Colors.green
                    : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _deleteTenant(context, tenant);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Tenant', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          final unit = tenant['units'];
          final unitNumber = unit is Map
              ? unit['unit_number']?.toString() ?? 'N/A'
              : 'N/A';
          _showTenantDetails(context, tenant, unitNumber);
        },
      ),
    );
  }

  Future<void> _deleteTenant(
    BuildContext context,
    Map<String, dynamic> tenant,
  ) async {
    final tenantId = tenant['id']?.toString();
    final tenantEmail = tenant['email']?.toString() ?? '';
    final tenantName = tenant['full_name']?.toString() ?? 'this tenant';

    if (tenantId == null || tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete tenant: missing tenant ID.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Tenant?'),
          content: Text(
            'Are you sure you want to permanently delete $tenantName?\\n\\n'
            'This will remove the tenant from the property and delete '
            'their JUMAA account access. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await _supabase.functions.invoke(
        'delete-tenant-account',
        body: {'tenant_id': tenantId, 'email': tenantEmail},
      );

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (response.data is Map && response.data['success'] == false) {
        throw Exception(
          response.data['error']?.toString() ?? 'Tenant deletion failed.',
        );
      }

      if (!context.mounted) return;

      await _loadTenants();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$tenantName has been permanently deleted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context)
            .popUntil((route) => route.isFirst || route.settings.name != null);
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete tenant: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
