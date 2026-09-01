import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/landlord.dart';
import '../../models/apartment.dart';
import '../../main.dart' show OpenNestStore;

import 'landlord_booking_page.dart';
import 'landlord_apartment_page.dart';
import 'landlord_tenants_page.dart';
import 'landlord_messages_page.dart';
import 'landlord_payments_page.dart';
import 'landlord_notifications_page.dart';
import 'landlord_announcements_page.dart';
import 'landlord_settings_page.dart';

class LandlordDashboardPage extends StatefulWidget {
  final Landlord landlord;
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onLogout;

  const LandlordDashboardPage({
    super.key,
    required this.landlord,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    required this.onLogout,
  });

  @override
  State<LandlordDashboardPage> createState() => _LandlordDashboardPageState();
}

class _LandlordDashboardPageState extends State<LandlordDashboardPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _currentIndex = 0;

  List<Apartment> _supabaseUnits = [];

  List<Apartment> get assignedUnits {
    if (_supabaseUnits.isNotEmpty) {
      return _supabaseUnits;
    }

    if (widget.landlord.propertyId.isNotEmpty) {
      final byId = OpenNestStore.apartments
          .where((unit) => unit.propertyId == widget.landlord.propertyId)
          .toList();

      if (byId.isNotEmpty) return byId;
    }

    if (widget.landlord.propertyName.isNotEmpty) {
      return OpenNestStore.apartments
          .where(
            (unit) =>
                unit.propertyName.trim().toLowerCase() ==
                widget.landlord.propertyName.trim().toLowerCase(),
          )
          .toList();
    }

    return [];
  }

  @override
  void initState() {
    super.initState();

    debugPrint(
      'LANDLORD DASHBOARD: initState '
      'landlord=${widget.landlord.fullName} '
      'property=${widget.landlord.propertyName} '
      'propertyId=${widget.landlord.propertyId}',
    );

    _loadLandlordUnits();
  }

  Future<void> _loadLandlordUnits() async {
    final propertyId = widget.landlord.propertyId.trim();

    debugPrint('LANDLORD DASHBOARD UNITS: loading for propertyId=$propertyId');

    if (propertyId.isEmpty) {
      debugPrint('LANDLORD DASHBOARD UNITS: propertyId is empty');

      if (!mounted) return;

      setState(() {
        _supabaseUnits = [];
      });

      return;
    }

    try {
      final response = await _supabase
          .from('units')
          .select(
            'id, property_id, unit_number, unit_type, '
            'rent, monthly_rent, status, description',
          )
          .eq('property_id', propertyId)
          .order('created_at', ascending: false);

      debugPrint(
        'LANDLORD DASHBOARD UNITS: Supabase returned '
        '${response.length} units',
      );

      final units = <Apartment>[];

      for (final row in response) {
        final rent = row['monthly_rent'] ?? row['rent'];

        final unit = Apartment(
          id: row['id']?.toString() ?? '',
          number: row['unit_number']?.toString() ?? '',
          type: row['unit_type']?.toString() ?? '',
          rent: rent?.toString() ?? '0',
          tenant: '',
          status: _normalizeLandlordUnitStatus(
            row['status']?.toString() ?? 'vacant',
          ),
          propertyId: row['property_id']?.toString() ?? '',
          propertyName: widget.landlord.propertyName,
          description: row['description']?.toString() ?? '',
        );

        units.add(unit);

        debugPrint(
          'LANDLORD DASHBOARD UNIT: '
          'id=${unit.id} '
          'number=${unit.number} '
          'status=${unit.status} '
          'propertyId=${unit.propertyId}',
        );
      }

      if (!mounted) return;

      setState(() {
        _supabaseUnits = units;
      });

      debugPrint(
        'LANDLORD DASHBOARD UNITS: assignedUnits=${_supabaseUnits.length}',
      );
    } catch (e, stackTrace) {
      debugPrint('LANDLORD DASHBOARD UNITS ERROR: $e');
      debugPrint('LANDLORD DASHBOARD UNITS STACK: $stackTrace');

      if (!mounted) return;

      setState(() {
        _supabaseUnits = [];
      });
    }
  }

  String _normalizeLandlordUnitStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'occupied':
        return 'Occupied';

      case 'under maintenance':
      case 'maintenance':
      case 'under_maintenance':
        return 'Under Maintenance';

      case 'vacant':
      default:
        return 'Vacant';
    }
  }

  int get occupiedCount =>
      assignedUnits.where((u) => u.status == 'Occupied').length;

  int get vacantCount =>
      assignedUnits.where((u) => u.status == 'Vacant').length;

  int get maintenanceCount =>
      assignedUnits.where((u) => u.status == 'Under Maintenance').length;

  void _openPage(int index) {
    debugPrint('LANDLORD NAV DEBUG: _openPage called with index=$index');

    setState(() {
      _currentIndex = index;
    });

    debugPrint('LANDLORD NAV DEBUG: currentIndex changed to $_currentIndex');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'LANDLORD DASHBOARD BUILD: currentIndex=$_currentIndex | '
      'booking page included=${true}',
    );

    final pages = [
      _buildDashboard(),
      LandlordBookingPage(landlord: widget.landlord),
      LandlordApartmentPage(landlord: widget.landlord),
      LandlordTenantsPage(landlord: widget.landlord),
      LandlordMessagesPage(landlord: widget.landlord),
      LandlordPaymentsPage(landlord: widget.landlord),
      LandlordNotificationsPage(landlord: widget.landlord),
      LandlordSettingsPage(
        landlord: widget.landlord,
        isDarkMode: widget.isDarkMode,
        onDarkModeChanged: widget.onDarkModeChanged,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 52,
        selectedIndex: _currentIndex,
        onDestinationSelected: _openPage,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
        ),

        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, size: 16),
            selectedIcon: Icon(Icons.dashboard, size: 16),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, size: 16),
            selectedIcon: Icon(Icons.calendar_month, size: 16),
            label: 'Booking',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined, size: 16),
            selectedIcon: Icon(Icons.apartment, size: 16),
            label: 'Apartment',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline, size: 16),
            selectedIcon: Icon(Icons.people, size: 16),
            label: 'Tenants',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline, size: 16),
            selectedIcon: Icon(Icons.chat_bubble, size: 16),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined, size: 16),
            selectedIcon: Icon(Icons.payments, size: 16),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined, size: 16),
            selectedIcon: Icon(Icons.notifications, size: 16),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, size: 16),
            selectedIcon: Icon(Icons.settings, size: 16),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final units = assignedUnits;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 18,
        title: const Text(
          'Landlord',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            iconSize: 21,
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => _openPage(6),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await OpenNestStore.loadPropertiesFromSupabase();
            await OpenNestStore.loadUnitsFromSupabase();

            if (mounted) {
              setState(() {});
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
            children: [
              _welcomeCard(),
              const SizedBox(height: 14),

              _sectionTitle('Unit overview'),
              const SizedBox(height: 8),

              _overview(),

              const SizedBox(height: 16),

              _sectionTitle('Quick actions'),
              const SizedBox(height: 8),

              _quickActions(),

              const SizedBox(height: 16),

              _sectionTitle('Apartment'),
              const SizedBox(height: 8),

              _apartmentCard(units),

              const SizedBox(height: 16),

              _sectionTitle('Recent units'),
              const SizedBox(height: 8),

              if (units.isEmpty)
                _emptyUnits()
              else
                ...units.take(4).map(_unitCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back 👋',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.landlord.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.landlord.propertyName.isNotEmpty
                      ? widget.landlord.propertyName
                      : 'My Apartment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }

  Widget _overview() {
    return Row(
      children: [
        Expanded(
          child: _overviewCard(
            'Total',
            assignedUnits.length.toString(),
            Icons.home_work_outlined,
            const Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _overviewCard(
            'Occupied',
            occupiedCount.toString(),
            Icons.people_outline,
            const Color(0xFF059669),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _overviewCard(
            'Vacant',
            vacantCount.toString(),
            Icons.home_outlined,
            const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _overviewCard(
            'Repair',
            maintenanceCount.toString(),
            Icons.build_outlined,
            const Color(0xFFDC2626),
          ),
        ),
      ],
    );
  }

  Widget _overviewCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    final actions = [
      _QuickAction(
        'Booking',
        Icons.calendar_month_outlined,
        const Color(0xFF4F46E5),
        () => _openPage(1),
      ),
      _QuickAction(
        'Units',
        Icons.apartment_outlined,
        const Color(0xFF0891B2),
        () => _openPage(2),
      ),
      _QuickAction(
        'Tenants',
        Icons.people_outline,
        const Color(0xFF059669),
        () => _openPage(3),
      ),
      _QuickAction(
        'Messages',
        Icons.chat_outlined,
        const Color(0xFFDB2777),
        () => _openPage(4),
      ),
      _QuickAction(
        'Payments',
        Icons.payments_outlined,
        const Color(0xFFD97706),
        () => _openPage(5),
      ),
      _QuickAction(
        'Alerts',
        Icons.notifications_none,
        const Color(0xFFDC2626),
        () => _openPage(6),
      ),
      _QuickAction(
        'News',
        Icons.campaign_outlined,
        const Color(0xFF7C3AED),
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  LandlordAnnouncementsPage(landlord: widget.landlord),
            ),
          );
        },
      ),
      _QuickAction(
        'Settings',
        Icons.settings_outlined,
        const Color(0xFF475569),
        () => _openPage(7),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (_, index) {
        final action = actions[index];

        return InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: action.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: action.color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: action.color.withValues(alpha: 0.10)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, size: 20, color: action.color),
                const SizedBox(height: 5),
                Text(
                  action.title,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _apartmentCard(List<Apartment> units) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPage(2),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.10),
                ),
                child: const Icon(
                  Icons.apartment,
                  size: 21,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.landlord.propertyName.isNotEmpty
                          ? widget.landlord.propertyName
                          : 'My Apartment',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${units.length} units • $occupiedCount occupied',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unitCard(Apartment unit) {
    final isOccupied = unit.status == 'Occupied';
    final isMaintenance = unit.status == 'Under Maintenance';

    final Color statusColor = isOccupied
        ? const Color(0xFF059669)
        : isMaintenance
        ? const Color(0xFFDC2626)
        : const Color(0xFFF59E0B);

    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 1),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isOccupied
                ? Icons.person_outline
                : isMaintenance
                ? Icons.build_outlined
                : Icons.home_outlined,
            size: 18,
            color: statusColor,
          ),
        ),
        title: Text(
          'Unit ${unit.number}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(unit.type, style: const TextStyle(fontSize: 10)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            unit.status,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyUnits() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.home_work_outlined,
              size: 32,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 7),
            const Text(
              'No units yet',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              'Your assigned apartment units will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction(this.title, this.icon, this.color, this.onTap);
}
