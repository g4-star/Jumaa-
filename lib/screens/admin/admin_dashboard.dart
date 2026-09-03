import 'package:flutter/material.dart';

import '../../models/apartment.dart';
import '../../models/property.dart';
import '../../models/landlord.dart';
import '../../main.dart' show OpenNestStore;
import '../owner/owner_notifications_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.apartments,
    required this.properties,
    required this.landlords,
    required this.onOpenApartments,
    required this.onOpenLandlords,
    required this.onOpenTenants,
    required this.onOpenMessages,
    required this.onOpenPayments,
    required this.onOpenSubscriptions,
    required this.onOpenSettings,
  });

  final List<Apartment> apartments;
  final List<Property> properties;
  final List<Landlord> landlords;

  final VoidCallback onOpenApartments;
  final VoidCallback onOpenLandlords;
  final VoidCallback onOpenTenants;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenSubscriptions;
  final VoidCallback onOpenSettings;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  static const Color primary = Color(0xFF4F46E5);
  static const Color blue = Color(0xFF2563EB);
  static const Color green = Color(0xFF16A34A);
  static const Color orange = Color(0xFFF59E0B);
  static const Color purple = Color(0xFF9333EA);

  Future<int> _getUnreadNotificationCount() async {
    final user = OpenNestStore.supabase.auth.currentUser;
    if (user == null) return 0;

    try {
      final response = await OpenNestStore.supabase
          .from('owner_notifications')
          .select('id')
          .eq('owner_id', user.id)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      debugPrint('OWNER NOTIFICATION COUNT ERROR: $e');
      return 0;
    }
  }

  int get occupied => widget.apartments
      .where((a) => a.status.toLowerCase() == 'occupied')
      .length;

  int get vacant =>
      widget.apartments.where((a) => a.status.toLowerCase() == 'vacant').length;

  int get maintenance => widget.apartments
      .where((a) => a.status.toLowerCase() == 'maintenance')
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'JUMAA Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          FutureBuilder<int>(
            future: _getUnreadNotificationCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OwnerNotificationsPage(),
                        ),
                      );

                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 7,
                      top: 7,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            try {
              await Future.wait([
                OpenNestStore.loadPropertiesFromSupabase(),
                OpenNestStore.loadUnitsFromSupabase(),
                OpenNestStore.loadLandlords(),
              ]);
            } catch (e) {
              debugPrint('Admin dashboard refresh failed: $e');
            }

            if (mounted) {
              setState(() {});
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.dashboard_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back 👋',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage your properties from one place.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _buildPropertySection(),

              const SizedBox(height: 22),

              const Text(
                'Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      Icons.apartment,
                      widget.apartments.length.toString(),
                      'Total Units',
                      blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      Icons.check_circle_outline,
                      occupied.toString(),
                      'Occupied',
                      green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      Icons.home_outlined,
                      vacant.toString(),
                      'Vacant',
                      orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      Icons.build_outlined,
                      maintenance.toString(),
                      'Maintenance',
                      purple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              _action(
                Icons.apartment,
                'View Apartments',
                'Manage apartments and units',
                widget.onOpenApartments,
              ),

              _action(
                Icons.badge_outlined,
                'Manage Landlords',
                'Add, edit and remove landlords',
                widget.onOpenLandlords,
              ),

              _action(
                Icons.people_outline,
                'Manage Tenants',
                'Search tenants and payment status',
                widget.onOpenTenants,
              ),

              _action(
                Icons.payments_outlined,
                'View Payments',
                'Track payments and receipts',
                widget.onOpenPayments,
              ),

              _action(
                Icons.notifications_outlined,
                'Maintenance / Notifications',
                'Requests, reminders and alerts',
                () {},
              ),

              _action(
                Icons.chat_outlined,
                'Messages',
                'Chat with registered landlords',
                widget.onOpenMessages,
              ),

              _action(
                Icons.workspace_premium_outlined,
                'Subscriptions',
                'Manage your JUMAA subscription',
                widget.onOpenSubscriptions,
              ),

              _action(
                Icons.settings_outlined,
                'Settings',
                'Profile, notifications and preferences',
                widget.onOpenSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertySection() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'My Properties',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onOpenApartments,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (widget.properties.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No properties added yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...widget.properties.map(
                (property) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.apartment)),
                  title: Text(
                    property.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    property.location.isEmpty
                        ? 'Location not provided'
                        : property.location,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onOpenApartments,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String title, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    Color color;

    switch (title) {
      case 'View Apartments':
        color = blue;
        break;
      case 'Manage Landlords':
        color = purple;
        break;
      case 'Manage Tenants':
        color = green;
        break;
      case 'View Payments':
        color = orange;
        break;
      case 'Maintenance / Notifications':
        color = Colors.redAccent;
        break;
      case 'Messages':
        color = Colors.teal;
        break;
      case 'Subscriptions':
        color = Colors.amber.shade800;
        break;
      default:
        color = primary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
