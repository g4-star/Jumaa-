import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/owner.dart';
import 'models/property.dart';
import 'models/apartment.dart';
import 'models/landlord.dart';
import 'models/tenant.dart';
import 'screens/admin/admin_dashboard.dart';
import 'services/booking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pdezijwjfqyulkkuhoun.supabase.co',
    publishableKey: 'sb_publishable_wFuJsdho3es8WrD4vkqC_A_8MLx_0ft',
  );

  // Load properties and units from Supabase before opening the application.
  // If Supabase is temporarily unavailable, the app can still start with
  // empty data and display the appropriate empty states.
  try {
    await Future.wait([
      OpenNestStore.loadPropertiesFromSupabase(),
      OpenNestStore.loadUnitsFromSupabase(),
      OpenNestStore.loadLandlords(),
    ]).timeout(const Duration(seconds: 3));
  } on TimeoutException {
    debugPrint('Startup data load timed out after 3 seconds.');
  } catch (e) {
    debugPrint('Startup data load failed: $e');
  }

  runApp(const ApartmentApp());
}

// After Supabase.initialize(), before runApp:

class ApartmentApp extends StatefulWidget {
  const ApartmentApp({super.key});

  @override
  State<ApartmentApp> createState() => _ApartmentAppState();
}

class _ApartmentAppState extends State<ApartmentApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('jumaa_dark_mode') ?? false;

    if (!mounted) return;

    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _setDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('jumaa_dark_mode', enabled);

    if (!mounted) return;

    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JUMAA',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF172033),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFE8EBF2), width: 1),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFE2E6EF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFE2E6EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFF4F46E5), width: 2),
          ),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF4F46E5),
          foregroundColor: Colors.white,
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF818CF8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1117),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF151923),
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),

        cardTheme: CardThemeData(
          color: const Color(0xFF181C25),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFF292F3D), width: 1),
          ),
        ),

        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF181C25),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6366F1),
          foregroundColor: Colors.white,
        ),
      ),
      home: const OpenNestAuthGate(),
    );
  }
}

// ============================================================
// AUTHENTICATION GATE
// ============================================================

class OpenNestAuthGate extends StatefulWidget {
  const OpenNestAuthGate({super.key});

  @override
  State<OpenNestAuthGate> createState() => _OpenNestAuthGateState();
}

class _OpenNestAuthGateState extends State<OpenNestAuthGate> {
  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final loggedIn = prefs.getBool('jumaa_logged_in') ?? false;
    final email = prefs.getString('jumaa_logged_in_email');

    if (loggedIn && email != null && email.trim().isNotEmpty) {
      await OpenNestStore.loadOwners();

      final owner = OpenNestStore.findOwnerByEmail(email);

      if (owner != null) {
        _loggedIn = true;
      } else {
        await prefs.remove('jumaa_logged_in');
        await prefs.remove('jumaa_logged_in_email');
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loggedIn) {
      return DashboardPage(
        isDarkMode: Theme.of(context).brightness == Brightness.dark,
        onDarkModeChanged: (enabled) {
          final state = context.findAncestorStateOfType<_ApartmentAppState>();
          state?._setDarkMode(enabled);
        },
      );
    }

    return const JUMAAWelcomePage();
  }
}

// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int currentIndex = 0;
  bool _loadingDashboardData = false;

  @override
  void initState() {
    super.initState();
    _reloadDashboardData();
  }

  Future<void> _reloadDashboardData() async {
    if (_loadingDashboardData) return;

    _loadingDashboardData = true;

    try {
      await Future.wait([
        OpenNestStore.loadPropertiesFromSupabase(),
        OpenNestStore.loadUnitsFromSupabase(),
        OpenNestStore.loadLandlords(),
      ]);
    } catch (e) {
      debugPrint('Dashboard data reload failed: $e');
    } finally {
      _loadingDashboardData = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  List<Widget> get pages => [
    AdminDashboardPage(
      apartments: OpenNestStore.apartments,
      properties: OpenNestStore.properties,
      landlords: OpenNestStore.landlords,
      onOpenApartments: () => _selectPage(1),
      onOpenLandlords: () => _selectPage(2),
      onOpenTenants: () => _selectPage(3),
      onOpenMessages: () => _selectPage(4),
      onOpenPayments: () => _selectPage(5),
      onOpenSubscriptions: () => _selectPage(6),
      onOpenSettings: () => _selectPage(7),
    ),
    const OwnerApartmentManagementPage(),
    const LandlordsPage(),
    const TenantsPage(),
    const ChatListScreen(),
    const PaymentsPage(),
    const _SubscriptionsPlaceholderPage(),
    SettingsPage(
      isDarkMode: widget.isDarkMode,
      onDarkModeChanged: widget.onDarkModeChanged,
    ),
  ];

  void _selectPage(int index) {
    if (!mounted) return;

    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: const NavigationBarThemeData(
          height: 42,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 6,
              height: 0.8,
            ),
          ),
          iconTheme: WidgetStatePropertyAll(
            IconThemeData(
              size: 11,
            ),
          ),
        ),
        child: NavigationBar(
          height: 42,
          selectedIndex: currentIndex,
          onDestinationSelected: _selectPage,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, size: 11),
              selectedIcon: Icon(Icons.dashboard, size: 11),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.apartment_outlined, size: 11),
              selectedIcon: Icon(Icons.apartment, size: 11),
              label: 'Apartments',
            ),
            NavigationDestination(
              icon: Icon(Icons.badge_outlined, size: 11),
              selectedIcon: Icon(Icons.badge, size: 11),
              label: 'Landlords',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline, size: 11),
              selectedIcon: Icon(Icons.people, size: 11),
              label: 'Tenants',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline, size: 11),
              selectedIcon: Icon(Icons.chat_bubble, size: 11),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(Icons.payments_outlined, size: 11),
              selectedIcon: Icon(Icons.payments, size: 11),
              label: 'Payments',
            ),
            NavigationDestination(
              icon: Icon(Icons.workspace_premium_outlined, size: 11),
              selectedIcon: Icon(Icons.workspace_premium, size: 11),
              label: 'Subscriptions',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, size: 11),
              selectedIcon: Icon(Icons.settings, size: 11),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// Temporary page.
// We will replace this with the real subscription system next.
class _SubscriptionsPlaceholderPage extends StatelessWidget {
  const _SubscriptionsPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.workspace_premium),
              title: Text('JUMAA Subscription'),
              subtitle: Text(
                'Subscription management will be connected to Supabase here.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// DASHBOARD HOME
// ============================================================

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    final apartments = OpenNestStore.apartments;
    final totalApartments = apartments.length;
    final occupied = apartments
        .where((apartment) => apartment.status == 'Occupied')
        .length;
    final vacant = apartments
        .where((apartment) => apartment.status == 'Vacant')
        .length;
    final maintenance = apartments
        .where((apartment) => apartment.status == 'Maintenance')
        .length;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            const Text(
              'JUMAA',
              style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'Welcome back 👋',
              style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              'Manage your apartment easily.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 8.0),
            ),

            const SizedBox(height: 5),

            Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.apartment,
                    value: totalApartments.toString(),
                    title: 'Apartments',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _statCard(
                    icon: Icons.people,
                    value: occupied.toString(),
                    title: 'Occupied',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.home_outlined,
                    value: vacant.toString(),
                    title: 'Vacant',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    icon: Icons.build,
                    value: maintenance.toString(),
                    title: 'Maintenance',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _actionButton(
              icon: Icons.apartment,
              title: 'View Apartments',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OwnerApartmentManagementPage(),
                  ),
                );
              },
            ),

            _actionButton(
              icon: Icons.badge_outlined,
              title: 'Manage Landlords',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LandlordsPage()),
                );
              },
            ),

            _actionButton(
              icon: Icons.people,
              title: 'Manage Tenants',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TenantsPage()),
                );
              },
            ),

            _actionButton(
              icon: Icons.payments,
              title: 'View Payments',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaymentsPage()),
                );
              },
            ),

            _actionButton(
              icon: Icons.build,
              title: 'Maintenance Requests',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MaintenancePage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _statCard({
    required IconData icon,
    required String value,
    required String title,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
      ),
      child: SizedBox(
        height: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 3,
            vertical: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 8,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  '$value $title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.w600,
                    height: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _actionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 3),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(
          horizontal: -4,
          vertical: -4,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 0,
        ),
        leading: Icon(
          icon,
          size: 14,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 8,
        ),
        onTap: onTap,
      ),
    );
  }
}

// ============================================================
// OWNER APARTMENT MANAGEMENT
// ============================================================

class OwnerApartmentManagementPage extends StatefulWidget {
  const OwnerApartmentManagementPage({super.key});

  @override
  State<OwnerApartmentManagementPage> createState() =>
      _OwnerApartmentManagementPageState();
}

class _OwnerApartmentManagementPageState
    extends State<OwnerApartmentManagementPage> {
  Property? get property {
    if (OpenNestStore.properties.isEmpty) {
      return null;
    }
    return OpenNestStore.properties.first;
  }

  List<Apartment> get units {
    final currentProperty = property;

    if (currentProperty == null) {
      return [];
    }

    return OpenNestStore.apartments
        .where((unit) => unit.propertyId == currentProperty.id)
        .toList();
  }

  int get occupied => units.where((unit) => unit.status == 'Occupied').length;

  int get vacant => units.where((unit) => unit.status == 'Vacant').length;

  int get maintenance =>
      units.where((unit) => unit.status == 'Maintenance').length;

  @override
  Widget build(BuildContext context) {
    final currentProperty = property;

    if (currentProperty == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Apartment Management',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'Add Property',
              icon: const Icon(Icons.add_home_work_outlined),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddPropertyPage()),
                );

                if (mounted) {
                  await OpenNestStore.loadPropertiesFromSupabase();
                  setState(() {});
                }
              },
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.apartment_outlined,
                  size: 70,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No property found',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your first property to start managing apartments.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddPropertyPage(),
                      ),
                    );

                    if (mounted) {
                      await OpenNestStore.loadPropertiesFromSupabase();
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.add_home_work_outlined),
                  label: const Text('Add Property'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Apartment Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Property',
            icon: const Icon(Icons.add_home_work_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPropertyPage()),
              );

              if (mounted) {
                await OpenNestStore.loadPropertiesFromSupabase();
                setState(() {});
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // PROPERTY HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B3D2E), Color(0xFF126B4F)],
                ),
              borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.apartment_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    currentProperty.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.white70,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          currentProperty.location.isEmpty
                              ? 'Location not provided'
                              : currentProperty.location,
                          style: const TextStyle(
                            color: Colors.white70,
                              fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Property Overview',
              style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            Row(
              children: [
                Expanded(
                  child: _managementStat(
                    'Total Units',
                    units.length.toString(),
                    Icons.home_work_outlined,
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: _managementStat(
                    'Occupied',
                    occupied.toString(),
                    Icons.people_outline,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Row(
              children: [
                Expanded(
                  child: _managementStat(
                    'Vacant',
                    vacant.toString(),
                    Icons.home_outlined,
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: _managementStat(
                    'Maintenance',
                    maintenance.toString(),
                    Icons.build_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Property Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _managementAction(
              icon: Icons.edit_outlined,
              title: 'Edit Property',
              subtitle: 'Change name, location, address and contact details',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OwnerEditPropertyPage(property: currentProperty),
                  ),
                ).then((_) {
                  if (mounted) {
                    setState(() {});
                  }
                });
              },
            ),

            _managementAction(
              icon: Icons.photo_library_outlined,
              title: 'Photos & Videos',
              subtitle: 'Manage the photos and videos shown publicly',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OwnerPropertyMediaPage(property: currentProperty),
                  ),
                ).then((_) {
                  if (mounted) {
                    setState(() {});
                  }
                });
              },
            ),

            _managementAction(
              icon: Icons.home_work_outlined,
              title: 'Manage Units',
              subtitle: 'Manage occupied, vacant and maintenance units',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OwnerUnitsManagementPage(property: currentProperty),
                  ),
                ).then((_) {
                  if (mounted) {
                    setState(() {});
                  }
                });
              },
            ),

            const SizedBox(height: 24),

            const Text(
              'Property Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      Icons.location_on_outlined,
                      'Location',
                      currentProperty.location,
                    ),
                    const Divider(height: 24),
                    _infoRow(
                      Icons.place_outlined,
                      'Address',
                      currentProperty.address,
                    ),
                    const Divider(height: 24),
                    _infoRow(
                      Icons.phone_outlined,
                      'Phone',
                      currentProperty.phone,
                    ),
                    const Divider(height: 24),
                    _infoRow(
                      Icons.email_outlined,
                      'Email',
                      currentProperty.email,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _managementStat(String title, String value, IconData icon) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      child: SizedBox(
        height: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 3,
            vertical: 0,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 8,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  '$value $title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.w600,
                    height: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _managementAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 15),
        onTap: onTap,
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 3),
              Text(
                value.isEmpty ? 'Not provided' : value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// OWNER EDIT PROPERTY PAGE
// ============================================================

class OwnerEditPropertyPage extends StatefulWidget {
  final Property property;

  const OwnerEditPropertyPage({super.key, required this.property});

  @override
  State<OwnerEditPropertyPage> createState() => _OwnerEditPropertyPageState();
}

class _OwnerEditPropertyPageState extends State<OwnerEditPropertyPage> {
  late final TextEditingController nameController;
  late final TextEditingController locationController;
  late final TextEditingController addressController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.property.name);
    locationController = TextEditingController(text: widget.property.location);
    addressController = TextEditingController(text: widget.property.address);
    phoneController = TextEditingController(text: widget.property.phone);
    emailController = TextEditingController(text: widget.property.email);
    descriptionController = TextEditingController(
      text: widget.property.description,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> saveProperty() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apartment name is required.')),
      );
      return;
    }

    try {
      // Save the property to Supabase.
      await OpenNestStore.supabase
          .from('properties')
          .update({
            'name': name,
            'location': locationController.text.trim(),
            'address': addressController.text.trim(),
            'phone': phoneController.text.trim(),
            'email': emailController.text.trim(),
            'description': descriptionController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.property.id);

      if (!mounted) return;

      // Update the local property after Supabase succeeds.
      widget.property.name = name;
      widget.property.location = locationController.text.trim();
      widget.property.address = addressController.text.trim();
      widget.property.phone = phoneController.text.trim();
      widget.property.email = emailController.text.trim();
      widget.property.description = descriptionController.text.trim();

      // Keep existing units synchronized with the property.
      for (final unit in OpenNestStore.apartments) {
        if (unit.propertyId == widget.property.id) {
          unit.propertyName = widget.property.name;
          unit.location = widget.property.location;
          unit.description = widget.property.description;
        }
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Property updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update property: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Property',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _input(
            controller: nameController,
            label: 'Apartment / Property Name',
            icon: Icons.apartment_outlined,
          ),
          _input(
            controller: locationController,
            label: 'Location',
            icon: Icons.location_on_outlined,
          ),
          _input(
            controller: addressController,
            label: 'Address',
            icon: Icons.place_outlined,
          ),
          _input(
            controller: phoneController,
            label: 'Contact Phone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          _input(
            controller: emailController,
            label: 'Contact Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          _input(
            controller: descriptionController,
            label: 'Description',
            icon: Icons.description_outlined,
            maxLines: 5,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saveProperty,
              icon: const Icon(Icons.save_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('SAVE CHANGES'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

// ============================================================
// PROPERTY MEDIA MANAGEMENT PAGE
// ============================================================

class OwnerPropertyMediaPage extends StatefulWidget {
  final Property property;

  const OwnerPropertyMediaPage({super.key, required this.property});

  @override
  State<OwnerPropertyMediaPage> createState() => _OwnerPropertyMediaPageState();
}

class _OwnerPropertyMediaPageState extends State<OwnerPropertyMediaPage> {
  @override
  Widget build(BuildContext context) {
    final images = widget.property.imagePaths;
    final videos = widget.property.videoPaths;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Photos & Videos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Property Photos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'These photos will be displayed on the public apartment page.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),

          if (images.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 55,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No apartment photos added yet.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...images.map(
              (path) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        images.remove(path);
                      });
                    },
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),

          const Text(
            'Property Videos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(
            'Videos can be connected to the property media system here.',
            style: TextStyle(color: Colors.grey.shade600),
          ),

          const SizedBox(height: 14),

          if (videos.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(25),
                child: Text(
                  'No apartment videos added yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...videos.map(
              (path) => Card(
                child: ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        videos.remove(path);
                      });
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// OWNER UNIT MANAGEMENT PAGE
// ============================================================

class OwnerUnitsManagementPage extends StatefulWidget {
  final Property property;

  const OwnerUnitsManagementPage({super.key, required this.property});

  @override
  State<OwnerUnitsManagementPage> createState() =>
      _OwnerUnitsManagementPageState();
}

class _OwnerUnitsManagementPageState extends State<OwnerUnitsManagementPage> {
  List<Apartment> get units {
    return OpenNestStore.apartments
        .where((unit) => unit.propertyId == widget.property.id)
        .toList();
  }

  Future<void> _addUnit() async {
    final numberController = TextEditingController();
    final typeController = TextEditingController();
    final rentController = TextEditingController();

    String selectedStatus = 'Vacant';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Add Unit',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: numberController,
                      decoration: const InputDecoration(
                        labelText: 'Unit Number',
                        hintText: 'e.g. A101',
                        prefixIcon: Icon(Icons.tag),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: typeController,
                      decoration: const InputDecoration(
                        labelText: 'Unit Type',
                        hintText: 'e.g. 2 Bedroom',
                        prefixIcon: Icon(Icons.bed_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: rentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Rent',
                        hintText: 'e.g. 25000',
                        prefixIcon: Icon(Icons.payments_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Unit Status',
                        prefixIcon: Icon(Icons.circle_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Vacant',
                          child: Text('Vacant'),
                        ),
                        DropdownMenuItem(
                          value: 'Occupied',
                          child: Text('Occupied'),
                        ),
                        DropdownMenuItem(
                          value: 'Maintenance',
                          child: Text('Maintenance'),
                        ),
                        DropdownMenuItem(
                          value: 'Reserved',
                          child: Text('Reserved'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedStatus = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('CANCEL'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final number = numberController.text.trim();
                    final type = typeController.text.trim();
                    final rent = rentController.text.trim();

                    if (number.isEmpty || type.isEmpty || rent.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please fill in unit number, type and rent.',
                          ),
                        ),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);

                    try {
                      await OpenNestStore.supabase.from('units').insert({
                        'property_id': widget.property.id,
                        'unit_number': number,
                        'unit_type': type,
                        'monthly_rent': double.tryParse(rent) ?? 0,
                        'status': selectedStatus.toLowerCase(),
                        'description': '',
                      });

                      if (!mounted) return;

                      navigator.pop(true);
                    } catch (e) {
                      if (!mounted) return;

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to add unit: $e'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('ADD UNIT'),
                ),
              ],
            );
          },
        );
      },
    );

    numberController.dispose();
    typeController.dispose();
    rentController.dispose();

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteUnit(Apartment unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Unit?'),
          content: Text(
            'Are you sure you want to delete unit ${unit.number}? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('CANCEL'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await OpenNestStore.supabase
          .from('units')
          .delete()
          .eq('property_id', unit.propertyId)
          .eq('unit_number', unit.number);

      await OpenNestStore.loadUnitsFromSupabase();

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unit ${unit.number} deleted successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete unit: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final propertyUnits = units;

    final occupied = propertyUnits.where((u) => u.status == 'Occupied').length;

    final vacant = propertyUnits.where((u) => u.status == 'Vacant').length;

    final maintenance = propertyUnits
        .where((u) => u.status == 'Maintenance')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Units',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Unit',
            onPressed: _addUnit,
            icon: const Icon(Icons.add),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUnit,
        icon: const Icon(Icons.add),
        label: const Text('Add Unit'),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
        children: [
          Text(
            widget.property.name,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 5),

          Text(
            '${propertyUnits.length} total units',
            style: TextStyle(color: Colors.grey.shade600),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _statusCard('Occupied', occupied, Icons.people_outline),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusCard('Vacant', vacant, Icons.home_outlined),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusCard(
                  'Maintenance',
                  maintenance,
                  Icons.build_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Units',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${propertyUnits.length}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ...propertyUnits.map(
            (unit) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 5,
                ),

                leading: CircleAvatar(
                  child: Text(
                    unit.number.length > 3
                        ? unit.number.substring(unit.number.length - 3)
                        : unit.number,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),

                title: Text(
                  unit.number,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                subtitle: Text(
                  '${unit.type} • ${unit.rent}\n'
                  '${unit.tenant.isEmpty ? 'No tenant' : unit.tenant}',
                ),

                isThreeLine: true,

                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _statusBadge(unit.status),

                    const SizedBox(width: 5),

                    IconButton(
                      tooltip: 'Delete unit',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteUnit(unit),
                    ),
                  ],
                ),

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerEditUnitPage(unit: unit),
                    ),
                  ).then((_) {
                    if (mounted) {
                      setState(() {});
                    }
                  });
                },
              ),
            ),
          ),

          if (propertyUnits.isEmpty)
            Padding(
              padding: const EdgeInsets.all(35),
              child: Column(
                children: [
                  const Icon(Icons.home_work_outlined, size: 55),
                  const SizedBox(height: 12),
                  const Text(
                    'No units are connected to this property yet.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _addUnit,
                    icon: const Icon(Icons.add),
                    label: const Text('ADD FIRST UNIT'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusCard(String title, int value, IconData icon) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.grey.shade200,
      ),
      child: Text(
        status,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ============================================================
// OWNER EDIT UNIT PAGE
// ============================================================

class OwnerEditUnitPage extends StatefulWidget {
  final Apartment unit;

  const OwnerEditUnitPage({super.key, required this.unit});

  @override
  State<OwnerEditUnitPage> createState() => _OwnerEditUnitPageState();
}

class _OwnerEditUnitPageState extends State<OwnerEditUnitPage> {
  late final TextEditingController numberController;
  late final TextEditingController typeController;
  late final TextEditingController rentController;
  late final TextEditingController tenantController;

  late String selectedStatus;

  @override
  void initState() {
    super.initState();

    numberController = TextEditingController(text: widget.unit.number);
    typeController = TextEditingController(text: widget.unit.type);
    rentController = TextEditingController(text: widget.unit.rent);
    tenantController = TextEditingController(text: widget.unit.tenant);

    selectedStatus = widget.unit.status;
  }

  @override
  void dispose() {
    numberController.dispose();
    typeController.dispose();
    rentController.dispose();
    tenantController.dispose();
    super.dispose();
  }

  void saveUnit() {
    widget.unit.number = numberController.text.trim();
    widget.unit.type = typeController.text.trim();
    widget.unit.rent = rentController.text.trim();
    widget.unit.tenant = tenantController.text.trim();
    widget.unit.status = selectedStatus;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unit updated successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit ${widget.unit.number}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: numberController,
            decoration: const InputDecoration(
              labelText: 'Unit Number',
              prefixIcon: Icon(Icons.tag),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: typeController,
            decoration: const InputDecoration(
              labelText: 'Unit Type',
              prefixIcon: Icon(Icons.bed_outlined),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: rentController,
            decoration: const InputDecoration(
              labelText: 'Rent',
              prefixIcon: Icon(Icons.payments_outlined),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: tenantController,
            decoration: const InputDecoration(
              labelText: 'Tenant',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 18),

          DropdownButtonFormField<String>(
            initialValue: selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Unit Status',
              prefixIcon: Icon(Icons.circle_outlined),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Vacant', child: Text('Vacant')),
              DropdownMenuItem(value: 'Occupied', child: Text('Occupied')),
              DropdownMenuItem(
                value: 'Maintenance',
                child: Text('Maintenance'),
              ),
              DropdownMenuItem(value: 'Reserved', child: Text('Reserved')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedStatus = value;
                });
              }
            },
          ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saveUnit,
              icon: const Icon(Icons.save_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('SAVE UNIT'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// APARTMENTS SCREEN
// ============================================================

// ============================================================
// PUBLIC PROPERTY DETAILS PAGE
// ============================================================

class PublicPropertyDetailsPage extends StatefulWidget {
  final Property property;

  const PublicPropertyDetailsPage({super.key, required this.property});

  @override
  State<PublicPropertyDetailsPage> createState() =>
      _PublicPropertyDetailsPageState();
}

class _PublicPropertyDetailsPageState extends State<PublicPropertyDetailsPage> {
  final PageController _pageController = PageController();

  int _currentPhoto = 0;
  late List<String> _photos;

  // Fallback photos used only when the owner has not uploaded
  // property photos yet.
  static const List<String> _fallbackPhotos = [
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c',
    'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c',
    'https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3',
    'https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde',
    'https://images.unsplash.com/photo-1600585154526-990dced4db0d',
  ];

  @override
  void initState() {
    super.initState();

    final uploadedPhotos = widget.property.imagePaths
        .where((photo) => photo.trim().isNotEmpty)
        .toList();

    if (uploadedPhotos.isNotEmpty) {
      _photos = List<String>.from(uploadedPhotos)..shuffle();
    } else {
      _photos = List<String>.from(_fallbackPhotos)..shuffle();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;

    final units = OpenNestStore.apartments
        .where((unit) => unit.propertyId == property.id)
        .toList();

    final availableUnits = units
        .where((unit) => unit.status.toLowerCase() == 'vacant')
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            title: const Text(
              'Apartment Details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            flexibleSpace: FlexibleSpaceBar(background: _photoGallery()),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PROPERTY NAME
                  Text(
                    property.name.trim().isEmpty ? 'Apartment' : property.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // LOCATION
                  if (property.location.trim().isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 21,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            property.location,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (property.address.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.home_outlined,
                          size: 20,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            property.address,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 22),

                  // QUICK PROPERTY STATS
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          icon: Icons.apartment_rounded,
                          value: '${units.length}',
                          label: 'Total Units',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          icon: Icons.check_circle_rounded,
                          value: '${availableUnits.length}',
                          label: 'Available',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ABOUT
                  const Text(
                    'About this apartment',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    property.description.trim().isEmpty
                        ? 'This apartment offers comfortable living spaces in a convenient location. Contact the landlord to learn more about availability and the available units.'
                        : property.description,
                    style: const TextStyle(
                      color: Colors.black54,
                      height: 1.6,
                      fontSize: 14.5,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // AVAILABLE UNITS
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Available Units',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${availableUnits.length} available',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (availableUnits.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'There are currently no vacant units in this apartment.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...availableUnits.map(_publicUnitCard),

                  const SizedBox(height: 30),

                  // ACTION BUTTONS
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _startChat,
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text(
                            'CHAT LANDLORD',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: FilledButton.icon(
                          onPressed: availableUnits.isEmpty
                              ? null
                              : _openBookingForm,
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: const Text(
                            'BOOK NOW',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoGallery() {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: _photos.length,
          onPageChanged: (index) {
            if (!mounted) return;

            setState(() {
              _currentPhoto = index;
            });
          },
          itemBuilder: (context, index) {
            final photo = _photos[index];

            // Owner-uploaded images are local files.
            if (!photo.startsWith('http://') && !photo.startsWith('https://')) {
              return Image.file(
                File(photo),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return _photoFallback();
                },
              );
            }

            // Fallback/network images.
            return Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return _photoFallback();
              },
            );
          },
        ),

        // DARK GRADIENT OVER PHOTO
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 110,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
        ),

        // PHOTO COUNTER
        Positioned(
          right: 16,
          bottom: 18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentPhoto + 1} / ${_photos.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // DOT INDICATORS
        Positioned(
          left: 16,
          bottom: 20,
          child: Row(
            children: List.generate(_photos.length > 7 ? 7 : _photos.length, (
              index,
            ) {
              final active = index == _currentPhoto;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 5),
                width: active ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.white54,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _photoFallback() {
    return Container(
      color: const Color(0xFF0B3D2E),
      child: const Center(
        child: Icon(Icons.apartment_rounded, color: Colors.white, size: 75),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 25),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _publicUnitCard(Apartment unit) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.home_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit ${unit.number}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unit.type,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unit.rent,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Available',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatListScreen()),
    );
  }

  void _openBookingForm() {
    _showBookingDialog();
  }

  void _showBookingDialog() {
    final property = widget.property;

    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final messageController = TextEditingController();

    final availableUnits = OpenNestStore.apartments
        .where(
          (unit) =>
              unit.propertyId == property.id &&
              unit.status.toLowerCase() == 'vacant',
        )
        .toList();

    String? selectedUnit = availableUnits.isNotEmpty
        ? availableUnits.first.number
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 720),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Book Now',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),

                      Text(
                        property.name,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (availableUnits.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Preferred Unit',
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                          items: availableUnits.map((unit) {
                            return DropdownMenuItem<String>(
                              value: unit.number,
                              child: Text(
                                '${unit.number} • ${unit.type} • ${unit.rent}',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setModalState(() {
                              selectedUnit = value;
                            });
                          },
                        ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: messageController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Message (optional)',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.message_outlined),
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty ||
                                emailController.text.trim().isEmpty ||
                                phoneController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter your name, email and phone number.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (selectedUnit == null ||
                                selectedUnit!.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a vacant unit.'),
                                ),
                              );
                              return;
                            }

                            final selectedApartment = availableUnits.firstWhere(
                              (unit) => unit.number == selectedUnit,
                              orElse: () => availableUnits.first,
                            );

                            try {
                              final bookingService = BookingService();

                              await bookingService.createBooking(
                                propertyId: property.id,
                                unitId: selectedApartment.id,
                                fullName: nameController.text,
                                email: emailController.text,
                                phone: phoneController.text,
                                message: messageController.text,
                              );

                              if (!context.mounted) return;

                              Navigator.pop(sheetContext);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Booking request submitted successfully.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to submit booking request: $e',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.send_rounded),
                          label: const Text(
                            'SUBMIT BOOKING REQUEST',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Center(
                        child: Text(
                          'The landlord will review your booking request.',
                          style: TextStyle(color: Colors.black45, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ManageApartmentsPage extends StatefulWidget {
  const ManageApartmentsPage({super.key});

  @override
  State<ManageApartmentsPage> createState() => _ManageApartmentsPageState();
}

class _ManageApartmentsPageState extends State<ManageApartmentsPage> {
  String _searchQuery = '';

  List<Property> get _properties => OpenNestStore.properties;

  List<Apartment> _unitsForProperty(String propertyId) {
    return OpenNestStore.apartments
        .where((unit) => unit.propertyId == propertyId)
        .toList();
  }

  void _refresh() {
    setState(() {});
  }

  void _openProperty(Property property) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ManagePropertyPage(property: property)),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();

    final properties = _properties.where((property) {
      if (query.isEmpty) {
        return true;
      }

      return property.name.toLowerCase().contains(query) ||
          property.location.toLowerCase().contains(query) ||
          property.address.toLowerCase().contains(query);
    }).toList();

    final totalUnits = OpenNestStore.apartments.length;
    final vacantUnits = OpenNestStore.apartments
        .where((unit) => unit.status == 'Vacant')
        .length;
    final occupiedUnits = OpenNestStore.apartments
        .where((unit) => unit.status == 'Occupied')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Apartments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search apartments...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    'Properties',
                    _properties.length.toString(),
                    Icons.apartment_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCard(
                    'Units',
                    totalUnits.toString(),
                    Icons.home_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCard(
                    'Vacant',
                    vacantUnits.toString(),
                    Icons.check_circle_outline,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Occupied Units'),
                trailing: Text(
                  occupiedUnits.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Properties',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddPropertyPage(),
                      ),
                    ).then((_) async {
                      await OpenNestStore.loadPropertiesFromSupabase();
                      if (mounted) {
                        setState(() {});
                      }
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (properties.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.apartment_outlined,
                        size: 55,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No apartments found',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Register a property to start managing apartments.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...properties.map(_propertyCard),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _propertyCard(Property property) {
    final units = _unitsForProperty(property.id);
    final vacant = units.where((unit) => unit.status == 'Vacant').length;
    final occupied = units.where((unit) => unit.status == 'Occupied').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openProperty(property),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.apartment_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (property.location.trim().isNotEmpty)
                          Text(
                            property.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  _statusChip('${units.length} units', Icons.home_outlined),
                  const SizedBox(width: 8),
                  _statusChip('$vacant vacant', Icons.check_circle_outline),
                  const SizedBox(width: 8),
                  _statusChip('$occupied occupied', Icons.person_outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String text, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManagePropertyPage extends StatefulWidget {
  final Property property;

  const ManagePropertyPage({super.key, required this.property});

  @override
  State<ManagePropertyPage> createState() => _ManagePropertyPageState();
}

class _ManagePropertyPageState extends State<ManagePropertyPage> {
  List<Apartment> get _units => OpenNestStore.apartments
      .where((unit) => unit.propertyId == widget.property.id)
      .toList();

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final units = _units;

    final vacant = units.where((unit) => unit.status == 'Vacant').length;
    final occupied = units.where((unit) => unit.status == 'Occupied').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          property.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (property.location.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      property.location,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                  if (property.address.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      property.address,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                  if (property.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      property.description,
                      style: const TextStyle(height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _metric(
                  'Total',
                  units.length.toString(),
                  Icons.home_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'Vacant',
                  vacant.toString(),
                  Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'Occupied',
                  occupied.toString(),
                  Icons.person_outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Units',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OwnerUnitsManagementPage(property: widget.property),
                    ),
                  );

                  if (mounted) {
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Unit'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (units.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'No units have been added to this property yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...units.map(_unitTile),
        ],
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitTile(Apartment unit) {
    final available = unit.status == 'Vacant';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OwnerEditUnitPage(unit: unit)),
          );

          if (mounted) {
            setState(() {});
          }
        },
        leading: CircleAvatar(
          child: Text(
            unit.number.length > 3
                ? unit.number.substring(unit.number.length - 3)
                : unit.number,
            style: const TextStyle(fontSize: 11),
          ),
        ),
        title: Text(
          unit.number,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${unit.type} • ${unit.rent}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(available ? Icons.check_circle_outline : Icons.person_outline),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class ApartmentsPage extends StatefulWidget {
  const ApartmentsPage({super.key});

  @override
  State<ApartmentsPage> createState() => _ApartmentsPageState();
}

class _ApartmentsPageState extends State<ApartmentsPage> {
  String searchQuery = '';

  String? selectedCounty;
  String? selectedSubcounty;
  String? selectedHouseType;

  double? minimumRent;
  double? maximumRent;

  List<Property> get properties => OpenNestStore.properties;

  List<Apartment> get apartments => OpenNestStore.apartments;

  List<Apartment> unitsForProperty(String propertyId) {
    return apartments.where((unit) => unit.propertyId == propertyId).toList();
  }

  Property? propertyById(String propertyId) {
    for (final property in properties) {
      if (property.id == propertyId) {
        return property;
      }
    }

    return null;
  }

  List<String> propertyImages(String propertyId) {
    final property = propertyById(propertyId);

    if (property == null) {
      return [];
    }

    return property.imagePaths.toSet().toList();
  }

  String propertyLocation(Property property) {
    final parts = <String>[];

    if (property.location.trim().isNotEmpty) {
      parts.add(property.location.trim());
    }

    if (property.subcounty.trim().isNotEmpty &&
        !parts.contains(property.subcounty.trim())) {
      parts.add(property.subcounty.trim());
    }

    if (property.county.trim().isNotEmpty &&
        !parts.contains(property.county.trim())) {
      parts.add(property.county.trim());
    }

    if (parts.isEmpty && property.address.trim().isNotEmpty) {
      return property.address.trim();
    }

    return parts.isEmpty ? 'Location not provided' : parts.join(', ');
  }

  String propertyDescription(Property property) {
    if (property.description.trim().isEmpty) {
      return 'Comfortable living spaces with convenient access to the surrounding area.';
    }

    return property.description.trim();
  }

  List<String> get availableCounties {
    final values = properties
        .map((property) => property.county.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    values.sort();
    return values;
  }

  List<String> get availableSubcounties {
    final values = properties
        .where(
          (property) =>
              selectedCounty == null ||
              selectedCounty!.isEmpty ||
              property.county.trim().toLowerCase() ==
                  selectedCounty!.trim().toLowerCase(),
        )
        .map((property) => property.subcounty.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    values.sort();
    return values;
  }

  List<String> get availableHouseTypes {
    final values = <String>{};

    for (final unit in apartments) {
      if (unit.type.trim().isNotEmpty) {
        values.add(unit.type.trim());
      }
    }

    return values.toList()..sort();
  }

  double _rentValue(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  bool _propertyMatches(Property property) {
    final query = searchQuery.trim().toLowerCase();

    if (query.isNotEmpty) {
      final searchable = [
        property.name,
        property.location,
        property.address,
        property.county,
        property.subcounty,
        property.description,
      ].join(' ').toLowerCase();

      if (!searchable.contains(query)) {
        return false;
      }
    }

    if (selectedCounty != null &&
        selectedCounty!.isNotEmpty &&
        property.county.trim().toLowerCase() !=
            selectedCounty!.trim().toLowerCase()) {
      return false;
    }

    if (selectedSubcounty != null &&
        selectedSubcounty!.isNotEmpty &&
        property.subcounty.trim().toLowerCase() !=
            selectedSubcounty!.trim().toLowerCase()) {
      return false;
    }

    final units = unitsForProperty(property.id);

    if (selectedHouseType != null && selectedHouseType!.isNotEmpty) {
      final matchingType = units.any(
        (unit) =>
            unit.type.trim().toLowerCase() ==
            selectedHouseType!.trim().toLowerCase(),
      );

      if (!matchingType) {
        return false;
      }
    }

    if (minimumRent != null || maximumRent != null) {
      final hasMatchingRent = units.any((unit) {
        final rent = _rentValue(unit.rent);

        if (minimumRent != null && rent < minimumRent!) {
          return false;
        }

        if (maximumRent != null && rent > maximumRent!) {
          return false;
        }

        return true;
      });

      if (!hasMatchingRent) {
        return false;
      }
    }

    return true;
  }

  List<Property> get filteredProperties {
    return properties.where(_propertyMatches).toList();
  }

  int availableUnits(Property property) {
    return unitsForProperty(property.id)
        .where((unit) => unit.status.toLowerCase() == 'vacant')
        .length;
  }

  void _clearFilters() {
    setState(() {
      selectedCounty = null;
      selectedSubcounty = null;
      selectedHouseType = null;
      minimumRent = null;
      maximumRent = null;
    });
  }

  bool get hasFilters {
    return selectedCounty != null ||
        selectedSubcounty != null ||
        selectedHouseType != null ||
        minimumRent != null ||
        maximumRent != null;
  }

  Future<void> _openFilters() async {
    String? tempCounty = selectedCounty;
    String? tempSubcounty = selectedSubcounty;
    String? tempHouseType = selectedHouseType;

    final minController = TextEditingController(
      text: minimumRent?.toStringAsFixed(0) ?? '',
    );

    final maxController = TextEditingController(
      text: maximumRent?.toStringAsFixed(0) ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final subcounties =
                properties
                    .where(
                      (property) =>
                          tempCounty == null ||
                          tempCounty!.isEmpty ||
                          property.county.trim().toLowerCase() ==
                              tempCounty!.trim().toLowerCase(),
                    )
                    .map((property) => property.subcounty.trim())
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 720),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Filter Apartments',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (hasFilters)
                            TextButton(
                              onPressed: () {
                                setSheetState(() {
                                  tempCounty = null;
                                  tempSubcounty = null;
                                  tempHouseType = null;
                                  minController.clear();
                                  maxController.clear();
                                });
                              },
                              child: const Text('Reset'),
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      DropdownButtonFormField<String>(
                        initialValue: tempCounty,
                        decoration: const InputDecoration(
                          labelText: 'County',
                          prefixIcon: Icon(Icons.location_city_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: availableCounties
                            .map(
                              (county) => DropdownMenuItem(
                                value: county,
                                child: Text(county),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            tempCounty = value;
                            tempSubcounty = null;
                          });
                        },
                      ),

                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        initialValue: tempSubcounty,
                        decoration: const InputDecoration(
                          labelText: 'Subcounty / Area',
                          prefixIcon: Icon(Icons.map_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: subcounties
                            .map(
                              (area) => DropdownMenuItem(
                                value: area,
                                child: Text(area),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            tempSubcounty = value;
                          });
                        },
                      ),

                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        initialValue: tempHouseType,
                        decoration: const InputDecoration(
                          labelText: 'House Type',
                          prefixIcon: Icon(Icons.home_work_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: availableHouseTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            tempHouseType = value;
                          });
                        },
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: minController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Min rent',
                                prefixText: 'KSh ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: maxController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max rent',
                                prefixText: 'KSh ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () {
                            final min = double.tryParse(
                              minController.text.trim(),
                            );

                            final max = double.tryParse(
                              maxController.text.trim(),
                            );

                            setState(() {
                              selectedCounty = tempCounty;
                              selectedSubcounty = tempSubcounty;
                              selectedHouseType = tempHouseType;
                              minimumRent = min;
                              maximumRent = max;
                            });

                            Navigator.pop(sheetContext);
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: const Text(
                            'APPLY FILTERS',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    minController.dispose();
    maxController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = filteredProperties;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Find an Apartment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search apartment or location...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          setState(() {
                            searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ACTIVE FILTERS
          if (hasFilters)
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (selectedCounty != null)
                    _filterChip(Icons.location_city_outlined, selectedCounty!),
                  if (selectedSubcounty != null)
                    _filterChip(Icons.map_outlined, selectedSubcounty!),
                  if (selectedHouseType != null)
                    _filterChip(Icons.home_work_outlined, selectedHouseType!),
                  if (minimumRent != null || maximumRent != null)
                    _filterChip(Icons.payments_outlined, _rentFilterLabel()),
                  ActionChip(
                    label: const Text('Clear'),
                    avatar: const Icon(Icons.close, size: 17),
                    onPressed: _clearFilters,
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text(
                  '${results.length} apartments',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (hasFilters)
                  Text(
                    'Filters active',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: results.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      return _propertyCard(results[index]);
                    },
                  ),
          ),
        ],
      ),

      // YOUR REQUESTED FILTER BUTTON AT THE BOTTOM
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _openFilters,
            icon: const Icon(Icons.tune_rounded),
            label: Text(
              hasFilters ? 'FILTERS ACTIVE' : 'FILTER APARTMENTS',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  String _rentFilterLabel() {
    if (minimumRent != null && maximumRent != null) {
      return 'KSh ${minimumRent!.toStringAsFixed(0)} - ${maximumRent!.toStringAsFixed(0)}';
    }

    if (minimumRent != null) {
      return 'From KSh ${minimumRent!.toStringAsFixed(0)}';
    }

    return 'Up to KSh ${maximumRent!.toStringAsFixed(0)}';
  }

  Widget _filterChip(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(avatar: Icon(icon, size: 16), label: Text(label)),
    );
  }

  Widget _propertyCard(Property property) {
    final units = unitsForProperty(property.id);
    final available = availableUnits(property);
    final images = propertyImages(property.id);

    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: primary.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: () => _showPropertyDetails(property),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 105,
              height: 118,
              child: _propertyImage(property, images),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: primary.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            propertyLocation(property),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    Text(
                      propertyDescription(property),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Colors.black45,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.apartment_rounded,
                                size: 11,
                                color: primary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${units.length}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 4),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 11,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$available available',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    SizedBox(
                      height: 25,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _showPropertyDetails(property),
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        child: const Text(
                          'VIEW APARTMENT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _propertyImage(Property property, List<String> images) {
    if (images.isEmpty) {
      return _propertyPlaceholder();
    }

    final imagePath = images.first;

    return SizedBox(
      height: 205,
      width: double.infinity,
      child: Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return _propertyPlaceholder();
        },
      ),
    );
  }

  Widget _propertyPlaceholder() {
    return SizedBox(
      height: 205,
      width: double.infinity,
      child: Container(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        child: Center(
          child: Icon(
            Icons.apartment_rounded,
            size: 70,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 15),
            const Text(
              'No apartments found',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 7),
            const Text(
              'Try another location, house type or rent range.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 18),
            if (hasFilters)
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Clear Filters'),
              ),
          ],
        ),
      ),
    );
  }

  void _showPropertyDetails(Property property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicPropertyDetailsPage(property: property),
      ),
    );
  }
}

// ============================================================
// PAYMENTS PAGE
// ============================================================

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await OpenNestStore.supabase
          .from('payments')
          .select('''
            id,
            tenant_id,
            property_id,
            unit_id,
            amount,
            payment_method,
            till_number,
            reference,
            status,
            payment_date,
            payment_destination
          ''')
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _payments = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });

      debugPrint('Payment loading failed: $e');
    }
  }

  int get _paidCount {
    return _payments.where((p) => p['status'] == 'paid').length;
  }

  int get _pendingCount {
    return _payments.where((p) {
      final status = p['status']?.toString() ?? 'pending';
      return status == 'pending' || status == 'processing';
    }).length;
  }

  int get _failedCount {
    return _payments.where((p) {
      return p['status'] == 'failed';
    }).length;
  }

  double get _totalPaid {
    return _payments.where((p) => p['status'] == 'paid').fold<double>(0, (
      total,
      payment,
    ) {
      return total +
          (double.tryParse(payment['amount']?.toString() ?? '0') ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: _loadPayments, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade500),
              const SizedBox(height: 12),
              const Text(
                'Could not load payments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadPayments,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPayments,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            children: [
              _summaryCard('Paid', '$_paidCount', Icons.check_circle),
              const SizedBox(width: 8),
              _summaryCard('Pending', '$_pendingCount', Icons.pending),
              const SizedBox(width: 8),
              _summaryCard('Failed', '$_failedCount', Icons.error),
            ],
          ),

          const SizedBox(height: 16),

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.account_balance_wallet)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total collected',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KSh ${_totalPaid.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Payment Records',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          if (_payments.isEmpty)
            _emptyPayments()
          else
            ..._payments.map(_paymentCard),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5),
          child: Column(
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyPayments() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.payments_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'No payments yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Payments made by tenants will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard(Map<String, dynamic> payment) {
    final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;

    final status = payment['status']?.toString() ?? 'pending';

    final reference = payment['reference']?.toString() ?? '';

    final destination = payment['payment_destination']?.toString() ?? '';

    final tillNumber = payment['till_number']?.toString() ?? '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showPaymentDetails(payment),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                child: Text(
                  status == 'paid' ? '✓' : 'KSh',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tenant payment',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Tenant ID: ${payment['tenant_id'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Property ID: ${payment['property_id'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    if (tillNumber.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Till: $tillNumber',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],

                    if (destination.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Destination: $destination',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],

                    if (reference.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Ref: $reference',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'KSh ${amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  _statusChip(status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    String label;

    switch (status) {
      case 'paid':
        label = 'Paid';
        break;
      case 'processing':
        label = 'Processing';
        break;
      case 'failed':
        label = 'Failed';
        break;
      case 'cancelled':
        label = 'Cancelled';
        break;
      default:
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: status == 'paid'
            ? Colors.green.withValues(alpha: 0.12)
            : status == 'failed'
            ? Colors.red.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: status == 'paid'
              ? Colors.green.shade700
              : status == 'failed'
              ? Colors.red.shade700
              : Colors.orange.shade700,
        ),
      ),
    );
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const Divider(height: 28),

              _detailRow('Amount', 'KSh ${amount.toStringAsFixed(2)}'),

              _detailRow(
                'Status',
                payment['status']?.toString().toUpperCase() ?? 'PENDING',
              ),

              _detailRow(
                'Payment method',
                payment['payment_method']?.toString() ?? 'till',
              ),

              _detailRow(
                'Till number',
                payment['till_number']?.toString() ?? 'Not available',
              ),

              _detailRow(
                'Destination',
                payment['payment_destination']?.toString() ?? 'Not available',
              ),

              _detailRow(
                'Reference',
                payment['reference']?.toString() ?? 'Not available',
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MAINTENANCE PAGE
// ============================================================

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Maintenance',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const Center(
        child: Text(
          'Maintenance',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class OpenNestStore {
  // ============================================================
  // SUPABASE
  // ============================================================

  static final SupabaseClient supabase = Supabase.instance.client;

  static String _normalizeUnitStatus(String status) {
    switch (status.toLowerCase().trim()) {
      case 'occupied':
        return 'Occupied';
      case 'reserved':
        return 'Reserved';
      case 'maintenance':
        return 'Maintenance';
      case 'vacant':
      default:
        return 'Vacant';
    }
  }

  // ============================================================
  // LOAD PROPERTIES FROM SUPABASE
  // ============================================================

  static double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static Future<void> loadPropertiesFromSupabase() async {
    final response = await supabase
        .from('properties')
        .select()
        .order('created_at', ascending: false);

    // Only replace local data when Supabase actually returned records.
    // This keeps the app usable if the database is empty.
    if (response.isEmpty) {
      debugPrint('Supabase: no properties found. Keeping local data.');
      return;
    }

    final loadedProperties = <Property>[];

    for (final row in response) {
      loadedProperties.add(
        Property(
          id: row['id']?.toString() ?? '',
          ownerId: row['owner_id']?.toString() ?? row['landlord_id']?.toString() ?? '',
          name: row['name']?.toString() ?? '',
          county: row['county']?.toString() ?? '',
          subcounty: row['subcounty']?.toString() ?? '',
          location: row['location']?.toString() ?? '',
          address: row['address']?.toString() ?? '',
          latitude: _toDouble(row['latitude']),
          longitude: _toDouble(row['longitude']),
          description: row['description']?.toString() ?? '',
          email: row['email']?.toString() ?? '',
          phone: row['phone']?.toString() ?? '',
          paymentMethod: row['payment_method']?.toString() ?? 'till',
          mpesaTillNumber: row['mpesa_till_number']?.toString() ?? '',
          mpesaPaybillNumber: row['mpesa_paybill_number']?.toString() ?? '',
          mpesaAccountNumber: row['mpesa_account_number']?.toString() ?? '',
          paymentsEnabled: row['payments_enabled'] == true,
        ),
      );
    }

    properties
      ..clear()
      ..addAll(loadedProperties);

    debugPrint('Supabase: loaded ${properties.length} properties.');
  }

  // ============================================================
  // LOAD UNITS FROM SUPABASE
  // ============================================================

  static Future<void> loadUnitsFromSupabase() async {
    final response = await supabase
        .from('units')
        .select()
        .order('created_at', ascending: false);

    // Keep local/sample units when the Supabase table is empty.
    if (response.isEmpty) {
      debugPrint('Supabase: no units found. Keeping local data.');
      return;
    }

    final loadedApartments = <Apartment>[];

    for (final row in response) {
      final rent = row['monthly_rent'];

      loadedApartments.add(
        Apartment(
          id: row['id']?.toString() ?? '',
          number: row['unit_number']?.toString() ?? '',
          type: row['unit_type']?.toString() ?? '',
          rent: rent?.toString() ?? '0',
          tenant: '',
          status: _normalizeUnitStatus(row['status']?.toString() ?? 'vacant'),
          propertyId: row['property_id']?.toString() ?? '',
          propertyName: '',
          location: '',
          description: row['description']?.toString() ?? '',
        ),
      );
    }

    apartments
      ..clear()
      ..addAll(loadedApartments);

    // Synchronize property information onto units.
    for (final unit in apartments) {
      Property? property;

      for (final candidate in properties) {
        if (candidate.id == unit.propertyId) {
          property = candidate;
          break;
        }
      }

      if (property != null) {
        unit.propertyName = property.name;
        unit.location = property.location;
      }
    }

    debugPrint('Supabase: loaded ${apartments.length} units.');
  }

  static Future<void> loadMarketplaceDataFromSupabase() async {
    await loadPropertiesFromSupabase();
    await loadUnitsFromSupabase();
  }

  // ============================================================
  // PROPERTIES
  // ============================================================

  // Data is loaded from Supabase.
  // No hardcoded properties or apartments.
  static final List<Property> properties = [];

  static final List<Apartment> apartments = [];

  static final List<Owner> owners = [];

  // ============================================================
  // OWNER PERSISTENCE
  // ============================================================

  static Future<void> loadOwners() async {
    final prefs = await SharedPreferences.getInstance();

    final count = prefs.getInt('owner_count') ?? 0;

    owners.clear();

    for (int i = 0; i < count; i++) {
      final email = prefs.getString('owner_${i}_email');

      if (email == null || email.isEmpty) {
        continue;
      }

      owners.add(
        Owner(
          id:
              prefs.getString('owner_${i}_id') ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          fullName: prefs.getString('owner_${i}_fullName') ?? '',
          email: email,
          phone: prefs.getString('owner_${i}_phone') ?? '',
          password: prefs.getString('owner_${i}_password') ?? '',
          propertyName: prefs.getString('owner_${i}_propertyName') ?? '',
          location: prefs.getString('owner_${i}_location') ?? '',
          units: prefs.getString('owner_${i}_units') ?? '',
          address: prefs.getString('owner_${i}_address') ?? '',
        ),
      );
    }
  }

  static Future<void> saveOwners() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('owner_count', owners.length);

    for (int i = 0; i < owners.length; i++) {
      final owner = owners[i];

      await prefs.setString('owner_${i}_id', owner.id);
      await prefs.setString('owner_${i}_fullName', owner.fullName);
      await prefs.setString('owner_${i}_email', owner.email);
      await prefs.setString('owner_${i}_phone', owner.phone);
      await prefs.setString('owner_${i}_password', owner.password);
      await prefs.setString('owner_${i}_propertyName', owner.propertyName);
      await prefs.setString('owner_${i}_location', owner.location);
      await prefs.setString('owner_${i}_units', owner.units);
      await prefs.setString('owner_${i}_address', owner.address);
    }
  }

  static Owner? findOwnerByEmail(String email) {
    final normalized = email.trim().toLowerCase();

    for (final owner in owners) {
      if (owner.email.trim().toLowerCase() == normalized) {
        return owner;
      }
    }

    return null;
  }

  static final List<Landlord> landlords = [];

  static Future<void> loadLandlords() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('landlord_count') ?? 0;

    landlords.clear();

    for (int i = 0; i < count; i++) {
      final email = prefs.getString('landlord_${i}_email');

      if (email == null || email.isEmpty) {
        continue;
      }

      landlords.add(
        Landlord(
          id:
              prefs.getString('landlord_${i}_id') ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          fullName: prefs.getString('landlord_${i}_fullName') ?? '',
          email: email,
          phone: prefs.getString('landlord_${i}_phone') ?? '',
          temporaryPassword: prefs.getString('landlord_${i}_password') ?? '',
          mustResetPassword: prefs.getBool('landlord_${i}_mustReset') ?? false,
          apartmentName: prefs.getString('landlord_${i}_apartment') ?? '',
          apartmentId: prefs.getString('landlord_${i}_apartmentId') ?? '',
        ),
      );
    }
  }

  static Future<void> saveLandlords() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('landlord_count', landlords.length);

    for (int i = 0; i < landlords.length; i++) {
      final landlord = landlords[i];

      await prefs.setString('landlord_${i}_id', landlord.id);
      await prefs.setString('landlord_${i}_fullName', landlord.fullName);
      await prefs.setString('landlord_${i}_email', landlord.email);
      await prefs.setString('landlord_${i}_phone', landlord.phone);
      await prefs.setString(
        'landlord_${i}_password',
        landlord.temporaryPassword,
      );
      await prefs.setBool(
        'landlord_${i}_mustReset',
        landlord.mustResetPassword,
      );
      await prefs.setString('landlord_${i}_apartment', landlord.apartmentName);
      await prefs.setString('landlord_${i}_apartmentId', landlord.apartmentId);
    }
  }

  static Landlord? findLandlordByEmail(String email) {
    final normalized = email.trim().toLowerCase();

    for (final landlord in landlords) {
      if (landlord.email.trim().toLowerCase() == normalized) {
        return landlord;
      }
    }

    return null;
  }

  static Future<void> savePropertyDescription({
    required String propertyId,
    required String description,
  }) async {
    if (propertyId.isEmpty) {
      throw Exception('Property ID is missing.');
    }

    await supabase
        .from('properties')
        .update({'description': description.trim()})
        .eq('id', propertyId);

    final propertyIndex = properties.indexWhere(
      (property) => property.id == propertyId,
    );

    if (propertyIndex != -1) {
      properties[propertyIndex].description = description.trim();
    }

    for (final unit in apartments) {
      if (unit.propertyId == propertyId) {
        unit.description = description.trim();
      }
    }
  }

  static Future<Landlord?> loadLandlordProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .eq('role', 'landlord')
        .maybeSingle();

    if (row == null) {
      return null;
    }

    final landlord = Landlord(
      id: row['id'] as String,
      fullName: row['full_name'] as String? ?? '',
      email: row['email'] as String? ?? user.email ?? '',
      phone: row['phone'] as String? ?? '',
      temporaryPassword: '',
      mustResetPassword: false,
      apartmentName: '',
      apartmentId: '',
    );

    landlords
      ..clear()
      ..add(landlord);

    return landlord;
  }

  static Future<Landlord?> loadLandlordById(String id) async {
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', id)
        .eq('role', 'landlord')
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return Landlord(
      id: row['id'] as String,
      fullName: row['full_name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      temporaryPassword: '',
      mustResetPassword: false,
      apartmentName: '',
      apartmentId: '',
    );
  }
}

class TenantsPage extends StatefulWidget {
  const TenantsPage({super.key});

  @override
  State<TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends State<TenantsPage> {
  String searchQuery = '';

  final List<Tenant> tenants = [];

  bool _loadingTenants = true;
  String? _tenantLoadError;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    if (mounted) {
      setState(() {
        _loadingTenants = true;
        _tenantLoadError = null;
      });
    }

    try {
      final response = await OpenNestStore.supabase
          .from('tenants')
          .select('''
            id,
            booking_request_id,
            property_id,
            unit_id,
            full_name,
            email,
            phone,
            account_status,
            move_in_date,
            units (
              unit_number,
              monthly_rent
            )
          ''')
          .order('created_at', ascending: false);

      final loadedTenants = <Tenant>[];

      for (final row in response) {
        final unit = row['units'];

        String unitNumber = '';
        String rent = 'KSh 0';

        if (unit is Map) {
          unitNumber = unit['unit_number']?.toString() ?? '';

          final monthlyRent = unit['monthly_rent'];

          if (monthlyRent != null) {
            rent = 'KSh $monthlyRent';
          }
        }

        loadedTenants.add(
          Tenant(
            id: row['id']?.toString() ?? '',
            bookingRequestId: row['booking_request_id']?.toString() ?? '',
            propertyId: row['property_id']?.toString() ?? '',
            unitId: row['unit_id']?.toString() ?? '',
            name: row['full_name']?.toString() ?? '',
            email: row['email']?.toString() ?? '',
            phone: row['phone']?.toString() ?? '',
            apartment: unitNumber,
            rent: rent,
            paymentStatus: 'Pending',
            accountStatus: row['account_status']?.toString() ?? 'active',
            moveInDate: row['move_in_date'] == null
                ? null
                : DateTime.tryParse(row['move_in_date'].toString()),
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        tenants
          ..clear()
          ..addAll(loadedTenants);
        _loadingTenants = false;
      });

      debugPrint('Supabase: loaded ${loadedTenants.length} tenants.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingTenants = false;
        _tenantLoadError = e.toString();
      });

      debugPrint('Supabase tenant load failed: $e');
    }
  }

  List<Tenant> get filteredTenants {
    final query = searchQuery.toLowerCase();

    return tenants.where((tenant) {
      return tenant.name.toLowerCase().contains(query) ||
          tenant.apartment.toLowerCase().contains(query) ||
          tenant.phone.contains(query);
    }).toList();
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
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),

      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search tenants...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _summaryItem(
                  'Tenants',
                  tenants.length.toString(),
                  Icons.people,
                ),
                const SizedBox(width: 10),
                _summaryItem(
                  'Paid',
                  tenants
                      .where((t) => t.paymentStatus == 'Paid')
                      .length
                      .toString(),
                  Icons.check_circle,
                ),
                const SizedBox(width: 10),
                _summaryItem(
                  'Pending',
                  tenants
                      .where((t) => t.paymentStatus != 'Paid')
                      .length
                      .toString(),
                  Icons.warning,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _loadingTenants
                ? const Center(child: CircularProgressIndicator())
                : _tenantLoadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 56,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Could not load tenants',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _tenantLoadError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _loadTenants,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : filteredTenants.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    onRefresh: _loadTenants,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: filteredTenants.length,
                      itemBuilder: (context, index) {
                        return _tenantCard(filteredTenants[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTenantDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Tenant'),
      ),
    );
  }

  Widget _summaryItem(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tenantCard(Tenant tenant) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showTenantDetails(tenant),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/jumaa_house_icon.png',
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        const Icon(Icons.apartment, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          tenant.apartment,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    Text(
                      tenant.phone,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _paymentBadge(tenant.paymentStatus),
                  const SizedBox(height: 6),
                  Text(
                    tenant.rent,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentBadge(String status) {
    Color color;

    switch (status) {
      case 'Paid':
        color = Colors.green;
        break;
      case 'Pending':
        color = Colors.orange;
        break;
      case 'Overdue':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  void _showTenantDetails(Tenant tenant) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    child: Text(
                      tenant.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tenant.phone,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 22),

              _tenantDetailRow(Icons.apartment, 'Apartment', tenant.apartment),

              _tenantDetailRow(Icons.payments, 'Monthly Rent', tenant.rent),

              _tenantDetailRow(
                Icons.account_balance_wallet,
                'Payment Status',
                tenant.paymentStatus,
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _editTenantDialog(tenant);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Tenant'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tenantDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showAddTenantDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final apartmentController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Tenant'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: apartmentController,
                      decoration: const InputDecoration(
                        labelText: 'Unit number',
                        prefixIcon: Icon(Icons.apartment),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final email = emailController.text.trim();
                          final phone = phoneController.text.trim();
                          final unitNumber = apartmentController.text
                              .trim()
                              .toUpperCase();

                          if (name.isEmpty ||
                              email.isEmpty ||
                              phone.isEmpty ||
                              unitNumber.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fill in all tenant details.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            final unitResponse = await OpenNestStore.supabase
                                .from('units')
                                .select(
                                  'id, property_id, monthly_rent, unit_number',
                                )
                                .eq('unit_number', unitNumber)
                                .maybeSingle();

                            if (unitResponse == null) {
                              throw Exception(
                                'Unit $unitNumber was not found.',
                              );
                            }

                            final unitId = unitResponse['id']?.toString() ?? '';
                            final propertyId =
                                unitResponse['property_id']?.toString() ?? '';
                            final monthlyRent = unitResponse['monthly_rent'];

                            if (unitId.isEmpty || propertyId.isEmpty) {
                              throw Exception(
                                'The selected unit is missing property information.',
                              );
                            }

                            final tenantResponse = await OpenNestStore.supabase
                                .from('tenants')
                                .insert({
                                  'property_id': propertyId,
                                  'unit_id': unitId,
                                  'full_name': name,
                                  'email': email,
                                  'phone': phone,
                                  'account_status': 'active',
                                })
                                .select()
                                .single();

                            final tenant = Tenant(
                              id: tenantResponse['id']?.toString() ?? '',
                              bookingRequestId:
                                  tenantResponse['booking_request_id']
                                      ?.toString() ??
                                  '',
                              propertyId: propertyId,
                              unitId: unitId,
                              name:
                                  tenantResponse['full_name']?.toString() ??
                                  name,
                              email:
                                  tenantResponse['email']?.toString() ?? email,
                              phone:
                                  tenantResponse['phone']?.toString() ?? phone,
                              apartment: unitNumber,
                              rent: 'KSh ${monthlyRent ?? 0}',
                              paymentStatus: 'Pending',
                              accountStatus:
                                  tenantResponse['account_status']
                                      ?.toString() ??
                                  'active',
                              moveInDate: tenantResponse['move_in_date'] == null
                                  ? null
                                  : DateTime.tryParse(
                                      tenantResponse['move_in_date'].toString(),
                                    ),
                            );

                            if (!mounted) return;

                            setState(() {
                              tenants.add(tenant);
                            });

                              if (!dialogContext.mounted) return;

                            Navigator.pop(dialogContext);

                              if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tenant added successfully.'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;

                            setDialogState(() {
                              saving = false;
                            });

                            if (!mounted) return;

                              if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not add tenant: $e'),
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Tenant'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editTenantDialog(Tenant tenant) {
    final nameController = TextEditingController(text: tenant.name);
    final phoneController = TextEditingController(text: tenant.phone);
    final apartmentController = TextEditingController(text: tenant.apartment);
    final rentController = TextEditingController(
      text: tenant.rent.replaceAll('KSh ', '').replaceAll(',', ''),
    );

    String status = tenant.paymentStatus;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Tenant'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    TextField(
                      controller: apartmentController,
                      decoration: const InputDecoration(labelText: 'Apartment'),
                    ),
                    TextField(
                      controller: rentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly rent',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Payment status',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                        DropdownMenuItem(
                          value: 'Pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'Overdue',
                          child: Text('Overdue'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            status = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      tenant.name = nameController.text.trim();
                      tenant.phone = phoneController.text.trim();
                      tenant.apartment = apartmentController.text
                          .trim()
                          .toUpperCase();
                      tenant.rent = 'KSh ${rentController.text.trim()}';
                      tenant.paymentStatus = status;
                    });

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 65, color: Colors.grey.shade400),
          const SizedBox(height: 15),
          const Text(
            'No tenants found',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LANDLORD MODEL
class LandlordLoginPage extends StatefulWidget {
  const LandlordLoginPage({super.key});

  @override
  State<LandlordLoginPage> createState() => _LandlordLoginPageState();
}

class _LandlordLoginPageState extends State<LandlordLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  Future<void> _login() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and password.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await OpenNestStore.supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const AuthException('Login failed.');
      }

      final landlord = await OpenNestStore.loadLandlordProfile();

      if (!mounted) return;

      if (landlord == null) {
        await OpenNestStore.supabase.auth.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This account is not registered as a landlord.'),
            behavior: SnackBarBehavior.floating,
          ),
        );

        setState(() {
          isLoading = false;
        });
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LandlordDashboardPage(landlord: landlord),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message.isNotEmpty ? e.message : 'Invalid email or password.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to sign in. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Landlord Login')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.business_outlined, size: 70),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome, Landlord',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to manage your assigned apartment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: isLoading ? null : _login,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('LOGIN'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LANDLORD PASSWORD RESET
// ============================================================

class LandlordResetPasswordPage extends StatefulWidget {
  final Landlord landlord;

  const LandlordResetPasswordPage({super.key, required this.landlord});

  @override
  State<LandlordResetPasswordPage> createState() =>
      _LandlordResetPasswordPageState();
}

class _LandlordResetPasswordPageState extends State<LandlordResetPasswordPage> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirm = true;

  Future<void> _resetPassword() async {
    final password = passwordController.text;
    final confirm = confirmController.text;

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your new password must be at least 8 characters.'),
        ),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The passwords do not match.')),
      );
      return;
    }

    // For the prototype we replace the temporary password.
    // Later this will be replaced by secure backend authentication.
    widget.landlord.temporaryPassword = password;
    widget.landlord.mustResetPassword = false;

    await OpenNestStore.saveLandlords();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LandlordDashboardPage(landlord: widget.landlord),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Create New Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.security_outlined, size: 70),
                  const SizedBox(height: 20),
                  const Text(
                    'Secure your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Welcome ${widget.landlord.fullName}. '
                    'Your temporary password has been accepted. '
                    'Create a new password to continue.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscureConfirm = !obscureConfirm;
                          });
                        },
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _resetPassword,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('SAVE NEW PASSWORD'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LANDLORD DASHBOARD
// ============================================================

class LandlordDashboardPage extends StatefulWidget {
  final Landlord landlord;

  const LandlordDashboardPage({super.key, required this.landlord});

  @override
  State<LandlordDashboardPage> createState() => _LandlordDashboardPageState();
}

class _LandlordDashboardPageState extends State<LandlordDashboardPage> {
  bool _loadingDashboardData = false;

  List<Apartment> get assignedApartments {
    // Prefer the landlord's property ID when available.
    if (widget.landlord.apartmentId.isNotEmpty) {
      final byId = OpenNestStore.apartments
          .where(
            (apartment) => apartment.propertyId == widget.landlord.apartmentId,
          )
          .toList();

      if (byId.isNotEmpty) {
        return byId;
      }
    }

    // Fallback to the property name.
    if (widget.landlord.apartmentName.isNotEmpty) {
      return OpenNestStore.apartments
          .where(
            (apartment) =>
                apartment.propertyName.trim().toLowerCase() ==
                widget.landlord.apartmentName.trim().toLowerCase(),
          )
          .toList();
    }

    return [];
  }

  int get occupiedCount =>
      assignedApartments.where((a) => a.status == 'Occupied').length;

  int get vacantCount =>
      assignedApartments.where((a) => a.status == 'Vacant').length;

  int get reservedCount =>
      assignedApartments.where((a) => a.status == 'Reserved').length;

  int get maintenanceCount =>
      assignedApartments.where((a) => a.status == 'Under Maintenance').length;

  Future<void> _reloadDashboardData() async {
    if (_loadingDashboardData) return;

    setState(() {
      _loadingDashboardData = true;
    });

    try {
      await Future.wait([
        OpenNestStore.loadPropertiesFromSupabase(),
        OpenNestStore.loadUnitsFromSupabase(),
        OpenNestStore.loadLandlords(),
      ]);
    } catch (e) {
      debugPrint('LANDLORD DASHBOARD RELOAD ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingDashboardData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartments = assignedApartments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Landlord Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              _showComingSoon(context, 'Notifications');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _reloadDashboardData();
          },
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                'Welcome, ${widget.landlord.fullName} 👋',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.landlord.apartmentName.isNotEmpty
                    ? widget.landlord.apartmentName
                    : 'My Property',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
              const SizedBox(height: 20),

              // ==================================================
              // OCCUPANCY SUMMARY
              // ==================================================
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      context,
                      Icons.home_work_outlined,
                      apartments.length.toString(),
                      'Units',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      context,
                      Icons.people_outline,
                      occupiedCount.toString(),
                      'Occupied',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      context,
                      Icons.home_outlined,
                      vacantCount.toString(),
                      'Vacant',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      context,
                      Icons.event_available_outlined,
                      reservedCount.toString(),
                      'Reserved',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      context,
                      Icons.build_outlined,
                      maintenanceCount.toString(),
                      'Maintenance',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              const Text(
                'Property Management',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              _actionTile(
                context,
                Icons.apartment_outlined,
                'My Apartments',
                'View units and manage occupancy',
                () => _showApartments(context),
              ),

              _actionTile(
                context,
                Icons.people_outline,
                'Tenants',
                'View tenants in your property',
                () => _showComingSoon(context, 'Tenants'),
              ),

              _actionTile(
                context,
                Icons.assignment_outlined,
                'Booking Requests',
                'Review and approve tenant bookings',
                () => _showComingSoon(context, 'Booking Requests'),
              ),

              _actionTile(
                context,
                Icons.payments_outlined,
                'Payments',
                'Paid, pending and overdue rent',
                () => _showComingSoon(context, 'Payments'),
              ),

              _actionTile(
                context,
                Icons.chat_outlined,
                'Messages',
                'Chat privately with your tenants',
                () => _showComingSoon(context, 'Messages'),
              ),

              _actionTile(
                context,
                Icons.campaign_outlined,
                'Announcements',
                'Send announcements to your tenants',
                () => _showComingSoon(context, 'Announcements'),
              ),

              _actionTile(
                context,
                Icons.notifications_outlined,
                'Notifications',
                'View property notifications',
                () => _showComingSoon(context, 'Notifications'),
              ),

              _actionTile(
                context,
                Icons.bar_chart_outlined,
                'Reports',
                'Occupancy and payment reports',
                () => _showComingSoon(context, 'Reports'),
              ),

              const SizedBox(height: 24),

              const Text(
                'Current Units',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              if (apartments.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.apartment_outlined,
                          size: 48,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No units assigned',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'There are currently no units assigned to this landlord.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...apartments.map(
                  (apartment) => _unitPreview(context, apartment),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _unitPreview(BuildContext context, Apartment apartment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            apartment.status == 'Occupied' ? Icons.person : Icons.home_outlined,
          ),
        ),
        title: Text(
          apartment.number,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${apartment.type} • ${apartment.rent}'),
        trailing: _statusChip(apartment.status),
        onTap: () => _editOccupancy(context, apartment),
      ),
    );
  }

  Widget _statusChip(String status) {
    return Chip(label: Text(status, style: const TextStyle(fontSize: 11)));
  }

  void _showApartments(BuildContext context) {
    final apartments = assignedApartments;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            builder: (_, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.all(18),
                children: [
                  const Text(
                    'My Apartments',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${apartments.length} unit(s)',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 18),
                  ...apartments.map(
                    (apartment) => Card(
                      child: ListTile(
                        title: Text(
                          apartment.number,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${apartment.type}\n'
                          '${apartment.rent}'
                          '${apartment.tenant.isNotEmpty ? '\nTenant: ${apartment.tenant}' : ''}',
                        ),
                        isThreeLine: apartment.tenant.isNotEmpty,
                        trailing: _statusChip(apartment.status),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _editOccupancy(context, apartment);
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _editOccupancy(BuildContext context, Apartment apartment) async {
    String selectedStatus = apartment.status;
    final tenantController = TextEditingController(text: apartment.tenant);

    const statuses = ['Vacant', 'Occupied', 'Reserved', 'Under Maintenance'];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final needsTenant =
                selectedStatus == 'Occupied' || selectedStatus == 'Reserved';

            return AlertDialog(
              title: Text('Edit ${apartment.number}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Occupancy Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: statuses.contains(selectedStatus)
                          ? selectedStatus
                          : 'Vacant',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: statuses
                          .map(
                            (status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedStatus = value;

                          if (value == 'Vacant' ||
                              value == 'Under Maintenance') {
                            tenantController.clear();
                          }
                        });
                      },
                    ),

                    if (needsTenant) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'Tenant',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tenantController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter tenant name',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (needsTenant && tenantController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a tenant before marking the unit occupied.',
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      apartment.status = selectedStatus;

                      if (selectedStatus == 'Vacant' ||
                          selectedStatus == 'Under Maintenance') {
                        apartment.tenant = '';
                      } else {
                        apartment.tenant = tenantController.text.trim();
                      }
                    });

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${apartment.number} updated successfully.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    tenantController.dispose();
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature will be connected next.')));
  }
}

// ============================================================
// LANDLORDS PAGE
// ============================================================

class LandlordsPage extends StatefulWidget {
  const LandlordsPage({super.key});

  @override
  State<LandlordsPage> createState() => _LandlordsPageState();
}

class _LandlordsPageState extends State<LandlordsPage> {
  void _showAddLandlordDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    String? selectedApartment;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Create Landlord Account',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedApartment,
                      decoration: const InputDecoration(
                        labelText: 'Assign apartment',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                      items: OpenNestStore.apartments
                          .map(
                            (apartment) => DropdownMenuItem<String>(
                              value: apartment.number,
                              child: Text(apartment.number),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedApartment = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Create Account'),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    final phone = phoneController.text.trim();

                    if (name.isEmpty ||
                        email.isEmpty ||
                        phone.isEmpty ||
                        selectedApartment == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please complete all landlord details.',
                          ),
                        ),
                      );
                      return;
                    }

                    final alreadyExists = OpenNestStore.landlords.any(
                      (landlord) =>
                          landlord.email.toLowerCase() == email.toLowerCase(),
                    );

                    if (alreadyExists) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'A landlord with this email already exists.',
                          ),
                        ),
                      );
                      return;
                    }

                    final id =
                        'ONL-${1000 + OpenNestStore.landlords.length + 1}';

                    final temporaryPassword =
                        'ON${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

                    final landlord = Landlord(
                      id: id,
                      fullName: name,
                      email: email,
                      phone: phone,
                      temporaryPassword: temporaryPassword,
                      mustResetPassword: true,
                      apartmentName: selectedApartment!,
                      apartmentId: selectedApartment!,
                    );

                    setState(() {
                      OpenNestStore.landlords.add(landlord);
                    });

                    Navigator.pop(dialogContext);

                    _showInvitation(landlord);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInvitation(Landlord landlord) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.mark_email_read_outlined),
              SizedBox(width: 10),
              Expanded(child: Text('Landlord Created')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to JUMAA! 🏠',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('${landlord.fullName} has been invited as a landlord.'),
                const SizedBox(height: 18),
                _credentialRow('Landlord ID', landlord.id),
                _credentialRow('Email', landlord.email),
                _credentialRow('Phone', landlord.phone),
                _credentialRow(
                  'Temporary password',
                  landlord.temporaryPassword,
                ),
                _credentialRow('Apartment', landlord.apartmentName),
                const SizedBox(height: 16),
                const Text(
                  'This temporary password is for first-time access only. '
                  'The landlord will be required to create a new password '
                  'after signing in.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _credentialRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final landlords = OpenNestStore.landlords;

    return Scaffold(
      appBar: AppBar(title: const Text('Landlords')),
      body: landlords.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 70,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No landlords yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create a landlord account and assign an apartment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _showAddLandlordDialog,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Landlord'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: landlords.length,
              itemBuilder: (context, index) {
                final landlord = landlords[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        landlord.fullName.isNotEmpty
                            ? landlord.fullName[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(
                      landlord.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${landlord.email}\n'
                      '${landlord.apartmentName} • ${landlord.id}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLandlordDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Landlord'),
      ),
    );
  }
}

// ============================================================
// TENANT MODEL
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true;
  String selectedLanguage = 'English';

  String managerName = 'Apartment Manager';
  String managerRole = 'Administrator';

  String defaultApartmentType = '1 Bedroom';
  bool showVacantFirst = false;
  bool requireApartmentNumber = true;

  int rentDueDay = 5;
  bool paymentReminders = true;
  bool autoMarkOverdue = true;

  // M-PESA payment destination for this property.
  String mpesaTillNumber = '';

  bool requireTenantPhone = true;
  bool preventDuplicateApartments = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: const CircleAvatar(
                radius: 28,
                child: Icon(Icons.person, size: 28),
              ),
              title: Text(
                managerName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(managerRole),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showProfileSettings,
            ),
          ),

          const SizedBox(height: 22),
          _sectionTitle('General'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  subtitle: Text(
                    notificationsEnabled
                        ? 'Notifications are enabled'
                        : 'Notifications are disabled',
                  ),
                  trailing: Switch(
                    value: notificationsEnabled,
                    onChanged: (value) {
                      setState(() => notificationsEnabled = value);
                      _showMessage(
                        value
                            ? 'Notifications enabled.'
                            : 'Notifications disabled.',
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  subtitle: Text(selectedLanguage),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showLanguageSettings,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark Mode'),
                  subtitle: Text(
                    widget.isDarkMode
                        ? 'Dark appearance is active'
                        : 'Light appearance is active',
                  ),
                  trailing: Switch(
                    value: widget.isDarkMode,
                    onChanged: (value) {
                      widget.onDarkModeChanged(value);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          _sectionTitle('Management'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.apartment),
                  title: const Text('Apartment Settings'),
                  subtitle: Text('Default type: $defaultApartmentType'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showApartmentSettings,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.payments),
                  title: const Text('Payment Settings'),
                  subtitle: Text('Rent due on day $rentDueDay of each month'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showPaymentSettings,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Tenant Settings'),
                  subtitle: Text(
                    requireTenantPhone
                        ? 'Phone number required'
                        : 'Phone number optional',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showTenantSettings,
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          _sectionTitle('Support'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  subtitle: const Text('Get help using JUMAA'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showHelpAndSupport,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: const Text('JUMAA v1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showAbout,
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),
          Center(
            child: Text(
              'JUMAA',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          const SizedBox(height: 5),
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),

          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Sign out of your JUMAA account'),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: _logout,
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'Are you sure you want to log out of your JUMAA account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('LOG OUT'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('jumaa_logged_in');
    await prefs.remove('jumaa_logged_in_email');

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JUMAAWelcomePage()),
      (route) => false,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showProfileSettings() async {
    final nameController = TextEditingController(text: managerName);
    final roleController = TextEditingController(text: managerRole);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profile Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roleController,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final role = roleController.text.trim();
              if (name.isEmpty || role.isEmpty) {
                _showMessage('Please enter both name and role.');
                return;
              }
              setState(() {
                managerName = name;
                managerRole = role;
              });
              Navigator.pop(dialogContext);
              _showMessage('Profile updated successfully.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameController.dispose();
    roleController.dispose();
  }

  void _showLanguageSettings() {
    String tempLanguage = selectedLanguage;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                RadioGroup<String>(
                  groupValue: tempLanguage,
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => tempLanguage = value);
                    }
                  },
                  child: Column(
                    children: [
                      const RadioListTile<String>(
                        value: 'English',
                        title: Text('English'),
                      ),
                      const RadioListTile<String>(
                        value: 'Swahili',
                        title: Text('Kiswahili'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() => selectedLanguage = tempLanguage);
                Navigator.pop(dialogContext);
                _showMessage('Language set to $tempLanguage.');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showApartmentSettings() {
    String tempType = defaultApartmentType;
    bool tempVacantFirst = showVacantFirst;
    bool tempRequireNumber = requireApartmentNumber;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Apartment Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: tempType,
                  decoration: const InputDecoration(
                    labelText: 'Default apartment type',
                    prefixIcon: Icon(Icons.bed),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Bedsitter',
                      child: Text('Bedsitter'),
                    ),
                    DropdownMenuItem(
                      value: '1 Bedroom',
                      child: Text('1 Bedroom'),
                    ),
                    DropdownMenuItem(
                      value: '2 Bedroom',
                      child: Text('2 Bedroom'),
                    ),
                    DropdownMenuItem(
                      value: '3 Bedroom',
                      child: Text('3 Bedroom'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => tempType = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show vacant apartments first'),
                  value: tempVacantFirst,
                  onChanged: (value) {
                    setDialogState(() => tempVacantFirst = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require apartment number'),
                  value: tempRequireNumber,
                  onChanged: (value) {
                    setDialogState(() => tempRequireNumber = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  defaultApartmentType = tempType;
                  showVacantFirst = tempVacantFirst;
                  requireApartmentNumber = tempRequireNumber;
                });
                Navigator.pop(dialogContext);
                _showMessage('Apartment settings saved.');
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentSettings() {
    final property = OpenNestStore.properties.isNotEmpty
        ? OpenNestStore.properties.first
        : null;

    if (property == null) {
      _showMessage('No property found for this account.');
      return;
    }

    int tempDueDay = rentDueDay;
    bool tempReminders = paymentReminders;
    bool tempAutoOverdue = autoMarkOverdue;
    bool tempPaymentsEnabled = property.paymentsEnabled;

    final tillController = TextEditingController(
      text: property.mpesaTillNumber,
    );

    final paybillController = TextEditingController(
      text: property.mpesaPaybillNumber,
    );

    final accountController = TextEditingController(
      text: property.mpesaAccountNumber,
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Payment Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: tempDueDay,
                  decoration: const InputDecoration(
                    labelText: 'Rent due day',
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  items: List.generate(
                    28,
                    (index) => DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text('Day ${index + 1}'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => tempDueDay = value);
                    }
                  },
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: tillController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'M-PESA Till Number',
                    hintText: 'Enter your M-PESA Till Number',
                    prefixIcon: Icon(Icons.store),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Tenants will use this Till Number when paying rent.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 16),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable payments'),
                  subtitle: const Text('Allow tenants to make rent payments'),
                  value: tempPaymentsEnabled,
                  onChanged: (value) {
                    setDialogState(() => tempPaymentsEnabled = value);
                  },
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Payment reminders'),
                  subtitle: const Text('Enable rent reminder notifications'),
                  value: tempReminders,
                  onChanged: (value) {
                    setDialogState(() => tempReminders = value);
                  },
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-mark overdue'),
                  subtitle: const Text('Mark unpaid rent as overdue'),
                  value: tempAutoOverdue,
                  onChanged: (value) {
                    setDialogState(() => tempAutoOverdue = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                tillController.dispose();
                paybillController.dispose();
                accountController.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final till = tillController.text.trim();

                if (tempPaymentsEnabled && till.isEmpty) {
                  _showMessage('Please enter your M-PESA Till Number.');
                  return;
                }

                try {
                  await OpenNestStore.supabase
                      .from('properties')
                      .update({
                        'payment_method': 'till',
                        'mpesa_till_number': till,
                        'mpesa_paybill_number': paybillController.text.trim(),
                        'mpesa_account_number': accountController.text.trim(),
                        'payments_enabled': tempPaymentsEnabled,
                      })
                      .eq('id', property.id);

                  property.paymentMethod = 'till';
                  property.mpesaTillNumber = till;
                  property.mpesaPaybillNumber = paybillController.text.trim();
                  property.mpesaAccountNumber = accountController.text.trim();
                  property.paymentsEnabled = tempPaymentsEnabled;

                  setState(() {
                    rentDueDay = tempDueDay;
                    paymentReminders = tempReminders;
                    autoMarkOverdue = tempAutoOverdue;
                  });

                  tillController.dispose();
                  paybillController.dispose();
                  accountController.dispose();

                    if (!dialogContext.mounted) return;

                  Navigator.pop(dialogContext);
                  _showMessage('Payment settings saved successfully.');
                } catch (e) {
                  _showMessage('Failed to save payment settings: $e');
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTenantSettings() {
    bool tempRequirePhone = requireTenantPhone;
    bool tempPreventDuplicates = preventDuplicateApartments;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tenant Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require phone number'),
                subtitle: const Text(
                  'Ask for a phone number when adding tenants',
                ),
                value: tempRequirePhone,
                onChanged: (value) {
                  setDialogState(() => tempRequirePhone = value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Prevent duplicate apartments'),
                subtitle: const Text(
                  'Avoid assigning the same apartment twice',
                ),
                value: tempPreventDuplicates,
                onChanged: (value) {
                  setDialogState(() => tempPreventDuplicates = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  requireTenantPhone = tempRequirePhone;
                  preventDuplicateApartments = tempPreventDuplicates;
                });
                Navigator.pop(dialogContext);
                _showMessage('Tenant settings saved.');
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpAndSupport() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Help & Support',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Need help? Use the options below or contact your application administrator.',
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Getting Started'),
                subtitle: const Text(
                  'Add apartments, then add tenants and manage payments.',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showMessage('Start by adding your apartments.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email Support'),
                subtitle: const Text('support@apartmentapp.local'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showMessage('Support email: support@apartmentapp.local');
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Call Support'),
                subtitle: const Text('+254 700 000 000'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showMessage('Support phone: +254 700 000 000');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'JUMAA',
      applicationVersion: '1.0.0',
      applicationIcon: const CircleAvatar(child: Icon(Icons.apartment)),
      children: const [
        SizedBox(height: 12),
        Text(
          'A simple apartment management app for managing apartments, tenants and payment status.',
        ),
      ],
    );
  }
}

// ============================================================
// JUMAA WELCOME / ENTRY SCREEN
// ============================================================

class JUMAAWelcomePage extends StatefulWidget {
  const JUMAAWelcomePage({super.key});

  @override
  State<JUMAAWelcomePage> createState() => _JUMAAWelcomePageState();
}

class _JUMAAWelcomePageState extends State<JUMAAWelcomePage> {
  final List<String> _houseImages = const [
    'assets/houses/house1.jpg',
    'assets/houses/house2.jpg',
    'assets/houses/house3.jpg',
    'assets/houses/house4.jpg',
    'assets/houses/house5.jpg',
    'assets/houses/house6.jpg',
  ];

  int _imageIndex = 0;
  Timer? _imageTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final image in _houseImages) {
        precacheImage(AssetImage(image), context);
      }
    });

    _imageTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;

      setState(() {
        _imageIndex = (_imageIndex + 1) % _houseImages.length;
      });
    });
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    super.dispose();
  }

  void _getStarted() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JUMAAEntryPage()),
    );
  }

  Widget _jumaaMeaning(String letter, String meaning) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          meaning,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width <= 400;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren,
                  ?currentChild,
                ],
              );
            },
            child: SizedBox.expand(
              key: ValueKey(_imageIndex),
              child: Image.asset(
                _houseImages[_imageIndex],
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.expand(
                    child: ColoredBox(color: Color(0xFF24332F)),
                  );
                },
              ),
            ),
          ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.20),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 20 : 28,
                vertical: 18,
              ),
              child: Column(
                children: [
                  const Spacer(),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Text(
                      'JUMAA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Find your next home.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 28 : 34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Discover apartments, connect with landlords, '
                    'and manage your home in one place.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: compact ? 13 : 15,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: compact ? 50 : 54,
                    child: FilledButton(
                      onPressed: _getStarted,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0B3D2E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'GET STARTED',
                            style: TextStyle(
                              fontSize: compact ? 13 : 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _jumaaMeaning('J', 'Join'),
                      _jumaaMeaning('U', 'Unite'),
                      _jumaaMeaning('M', 'Move'),
                      _jumaaMeaning('A', 'Access'),
                      _jumaaMeaning('A', 'Anywhere'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// JUMAA ENTRY PAGE
// ============================================================

class JUMAAEntryPage extends StatefulWidget {
  const JUMAAEntryPage({super.key});

  @override
  State<JUMAAEntryPage> createState() => _JUMAAEntryPageState();
}

class _JUMAAEntryPageState extends State<JUMAAEntryPage> {
  final List<String> _houseImages = const [
    'assets/houses/house1.jpg',
    'assets/houses/house2.jpg',
    'assets/houses/house3.jpg',
    'assets/houses/house4.jpg',
    'assets/houses/house5.jpg',
    'assets/houses/house6.jpg',
  ];

  String _backgroundImage = '';

  @override
  void initState() {
    super.initState();

    final random = DateTime.now().millisecondsSinceEpoch;
    _backgroundImage = _houseImages[random % _houseImages.length];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(AssetImage(_backgroundImage), context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 400;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // RANDOM HOUSE BACKGROUND
          Image.asset(
            _backgroundImage,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              return Container(color: const Color(0xFF0B3D2E));
            },
          ),

          // DARK OVERLAY FOR READABILITY
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),

          SafeArea(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 20 : 28,
                vertical: 18,
              ),
              children: [
                // BACK BUTTON
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: compact ? 35 : 55),

                // BRAND ICON
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.home_work_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'JUMAA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Your home journey starts here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                SizedBox(height: compact ? 30 : 42),

                // SECTION TITLE
                Text(
                  'What would you like to do?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 18),

                // FIND APARTMENT
                _entryOption(
                  context,
                  icon: Icons.search_rounded,
                  title: 'Find an Apartment',
                  subtitle: 'Discover a place that feels like home',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ApartmentsPage()),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // REGISTER APARTMENT
                _entryOption(
                  context,
                  icon: Icons.apartment_rounded,
                  title: 'Register an Apartment',
                  subtitle: 'List and manage your property',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterApartmentPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // LOGIN
                _entryOption(
                  context,
                  icon: Icons.login_rounded,
                  title: 'Login',
                  subtitle: 'Access your JUMAA account',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JUMAALoginPage()),
                    );
                  },
                ),

                const SizedBox(height: 30),

                Text(
                  'JOIN • UNITE • MOVE • ACCESS • ANYWHERE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 9,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.white.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Colors.white, size: 25),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.75),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// JUMAA - ADD PROPERTY FOR EXISTING OWNER
// ============================================================

// ============================================================

class AddPropertyPage extends StatefulWidget {
  const AddPropertyPage({super.key});

  @override
  State<AddPropertyPage> createState() => _AddPropertyPageState();
}

class _AddPropertyPageState extends State<AddPropertyPage> {
  final _formKey = GlobalKey<FormState>();

  final _propertyNameController = TextEditingController();
  final _unitsController = TextEditingController();
  final _addressController = TextEditingController();

  static const Map<String, Map<String, List<String>>> _kenyaLocations = {
    'Baringo': {
      'Baringo Central': ['Kabarnet', 'Sacho', 'Ewalel', 'Tenges'],
      'Baringo North': ['Kabartonjo', 'Barwessa', 'Sibilo', 'Bartabwa'],
      'East Pokot': ['Chepchoina', 'Chemolingot', 'Kolloa', 'Churo'],
      'Mogotio': ['Mogotio', 'Emining', 'Lembus', 'Solian'],
      'Marigat': ['Marigat', 'Ilchamus', 'Mochongoi', 'Nginyang'],
      'Tiaty': ['Chemolingot', 'Churo', 'Tangulbei', 'Silale'],
    },
    'Bomet': {
      'Bomet Central': ['Bomet Town', 'Longisa', 'Mutarakwa', 'Silibwet'],
      'Bomet East': ['Kaplong', 'Chebunyo', 'Koiwa', 'Merigi'],
      'Chepalungu': ['Sigor', 'Siongiroi', 'Chebunyo', 'Kongasis'],
      'Konoin': ['Chebunyo', 'Mogogosiek', 'Boito', 'Kimulot'],
      'Sotik': ['Sotik Town', 'Chemagel', 'Ndanai', 'Kaplong'],
    },
    'Bungoma': {
      'Bumula': ['Bumula', 'Khasoko', 'Siboti', 'South Bukusu'],
      'Bungoma Central': ['Bungoma Town', 'Kanduyi', 'Township', 'Musikoma'],
      'Bungoma East': ['Chwele', 'Ndivisi', 'Kabuchai', 'Mukuyuni'],
      'Bungoma North': ['Tongaren', 'Naitiri', 'Mbakalo', 'Mukhweya'],
      'Bungoma South': ['Webuye', 'Misikhu', 'Lugari', 'Matete'],
      'Kimilili': ['Kimilili', 'Maeni', 'Kibingei', 'Kamukuywa'],
      'Mt Elgon': ['Kapsokwony', 'Cheptais', 'Kaptama', 'Kaptoboi'],
    },
    'Busia': {
      'Bunyala': ['Bunyala', 'Budalangi', 'Port Victoria', 'Namboboto'],
      'Butula': ['Butula', 'Kingandole', 'Elugulu', 'Marachi'],
      'Samia': ['Funyula', 'Agenga', 'Nangina', 'Namboboto'],
      'Teso North': ['Amagoro', 'Malaba', 'Angurai', 'Malakisi'],
      'Teso South': ['Amukura', 'Angorom', 'Asinge', 'Angorom'],
      'Matayos': ['Matayos', 'Busia Town', 'Burumba', 'Mayenje'],
    },
    'Elgeyo-Marakwet': {
      'Keiyo North': ['Iten', 'Kapsowar', 'Kaptarakwa', 'Chepkorio'],
      'Keiyo South': ['Chepkorio', 'Kaptagat', 'Kamariny', 'Metkei'],
      'Marakwet East': ['Kapyego', 'Kapsowar', 'Arror', 'Tot'],
      'Marakwet West': ['Kapsowar', 'Cheptongei', 'Lelan', 'Kapsait'],
    },
    'Embu': {
      'Manyatta': ['Embu Town', 'Kithimu', 'Nginda', 'Gichiche'],
      'Mbeere North': ['Siakago', 'Nthawa', 'Muminji', 'Evurore'],
      'Mbeere South': ['Kiritiri', 'Gachoka', 'Ishiara', 'Makima'],
      'Runyenjes': ['Runyenjes', 'Kagaari', 'Kyeni', 'Gichiche'],
    },
    'Garissa': {
      'Daadab': ['Daadab', 'Liboi', 'Damajale', 'Abakaile'],
      'Fafi': ['Bura', 'Jarajila', 'Fafi', 'Bura East'],
      'Garissa Township': ['Garissa Town', 'Waberi', 'Galbet', 'Township'],
      'Hulugho': ['Hulugho', 'Sangailu', 'Bura'],
      'Ijara': ['Masalani', 'Ijara', 'Kotile', 'Sangailu'],
      'Lagdera': ['Modogashe', 'Benane', 'Baraki', 'Goreale'],
    },
    'Homa Bay': {
      'Homa Bay Town': ['Homa Bay Town', 'Asego', 'Kanyabala', 'Kojwach'],
      'Kabondo Kasipul': ['Kabondo', 'Kasipul', 'Kokwanyo', 'Kojwach'],
      'Karachuonyo': ['Kendu Bay', 'Wangchieng', 'Kibiri', 'Central'],
      'Kasipul': ['Oyugis', 'Kojwach', 'Kokoth Kat', 'Kabondo'],
      'Mbita': ['Mbita Town', 'Rusinga', 'Mfangano', 'Lambwe'],
      'Ndhiwa': ['Ndhiwa', 'Kandiege', 'Kochia', 'Kabuoch'],
      'Suba': ['Sori', 'Gwassi', 'Kaksingri', 'Magunga'],
    },
    'Isiolo': {
      'Isiolo Central': ['Isiolo Town', 'Burat', 'Ngaremara', 'Bulapesa'],
      'Isiolo North': ['Merti', 'Kinna', 'Oldonyiro', 'Sericho'],
    },
    'Kajiado': {
      'Kajiado Central': ['Kajiado Town', 'Purko', 'Elangata Wuas', 'Namanga'],
      'Kajiado North': ['Ngong', 'Oloolua', 'Olkeri', 'Nkaimurunya'],
      'Kajiado South': ['Loitokitok', 'Kimana', 'Entonet', 'Rombo'],
      'Kajiado East': ['Kitengela', 'Kaputiei', 'Imaroro', 'Kajiado'],
      'Kajiado West': ['Magadi', 'Ewuaso Kedong', 'Ilmarba', 'Keek Onke'],
    },
    'Kakamega': {
      'Butere': ['Butere', 'Marama', 'Shirere', 'Shitoto'],
      'Kakamega Central': ['Kakamega Town', 'Shieywe', 'Bukhungu', 'Lurambi'],
      'Kakamega East': ['Shinyalu', 'Isukha', 'Murhanda', 'Shirere'],
      'Kakamega North': ['Malava', 'Butali', 'Chemuche', 'Shirere'],
      'Kakamega South': ['Khwisero', 'Mumias', 'Shinyalu', 'Lurambi'],
      'Lugari': ['Lugari', 'Mautuma', 'Lumakanda', 'Matete'],
      'Matungu': ['Matungu', 'Koyonzo', 'Kholera', 'Mayoni'],
      'Mumias East': ['Mumias', 'Lubinu', 'Lubao', 'Namamali'],
    },
    'Kericho': {
      'Ainamoi': ['Kericho Town', 'Kapkugerwet', 'Kipchebor', 'Chepseon'],
      'Belgut': ['Sosiot', 'Kabianga', 'Kapkugerwet', 'Chepseon'],
      'Bureti': ['Litein', 'Cheborge', 'Kapkatet', 'Chebunyo'],
      'Kipkelion East': ['Londiani', 'Tendeno', 'Kedowa', 'Kipkelion'],
      'Kipkelion West': ['Kipkelion', 'Kunyak', 'Kamasian', 'Chilchila'],
      'Soin Sigowet': ['Sigowet', 'Soin', 'Soliat', 'Kapkugerwet'],
    },
    'Kiambu': {
      'Gatundu North': ['Gatundu', 'Kiamwangi', 'Kanjuku', 'Githobokoni'],
      'Gatundu South': ['Gatundu South', 'Kiamwangi', 'Ngenda', 'Kiganjo'],
      'Githunguri': ['Githunguri', 'Ikinu', 'Githiga', 'Kiairia'],
      'Juja': ['Juja', 'Kalimoni', 'Murera', 'Theta'],
      'Kabete': ['Kabete', 'Uthiru', 'Wangige', 'Gitaru'],
      'Kiambaa': ['Kiambu', 'Karuri', 'Muchatha', 'Ciiko'],
      'Kiambu Town': ['Kiambu Town', 'Tinganga', 'Ndumberi', 'Ruaka'],
      'Kikuyu': ['Kikuyu', 'Zambezi', 'Karai', 'Nachu'],
      'Limuru': ['Limuru', 'Tigoni', 'Ndeiya', 'Bibirioni'],
      'Ruiru': ['Ruiru', 'Kahawa', 'Githurai', 'Kimbo'],
      'Thika Town': ['Thika Town', 'Makongeni', 'Section 9', 'Gatuanyaga'],
      'Lari': ['Lari', 'Kijabe', 'Kinale', 'Nyanduma'],
    },
    'Kilifi': {
      'Kilifi North': ['Kilifi Town', 'Tezo', 'Mnarani', 'Sokoni'],
      'Kilifi South': ['Shimo la Tewa', 'Mtwapa', 'Chasimba', 'Mtepeni'],
      'Kaloleni': ['Kaloleni', 'Mariakani', 'Mwanamwinga', 'Kayafungo'],
      'Rabai': ['Rabai', 'Ruruma', 'Mwawesa', 'Kambe'],
      'Ganze': ['Ganze', 'Bamba', 'Jaribuni', 'Vitengeni'],
      'Malindi': ['Malindi Town', 'Ganda', 'Shela', 'Watamu'],
      'Magarini': ['Marafa', 'Gongoni', 'Adu', 'Garashi'],
    },
    'Kirinyaga': {
      'Kirinyaga Central': ['Kerugoya', 'Kutus', 'Kibirigwi', 'Mutira'],
      'Kirinyaga East': ['Kagio', 'Kutus', 'Njukiini', 'Kanyekini'],
      'Kirinyaga West': ['Baricho', 'Kiamaina', 'Kibirigwi', 'Ndia'],
      'Mwea East': ['Wanguru', 'Makutano', 'Kangai', 'Murinduko'],
      'Mwea West': ['Kagio', 'Kutus', 'Wamumu', 'Thiba'],
    },
    'Kisii': {
      'Bobasi': ['Ogembo', 'Nyamache', 'Masige', 'Bobasi'],
      'Bomachoge Borabu': ['Etago', 'Nyamache', 'Moticho', 'Boochi'],
      'Bomachoge Chache': ['Kisii Town', 'Mosocho', 'Masige', 'Boochi'],
      'Bonchari': ['Riana', 'Bobaracho', 'Mariba', 'Bonyando'],
      'Kitutu Chache North': ['Kisii Town', 'Keumbu', 'Sensi', 'Birongo'],
      'Kitutu Chache South': ['Masaba', 'Nyatieko', 'Bogeka', 'Mosocho'],
      'Nyaribari Chache': [
        'Kisii Town',
        'Kisii Central',
        'Keumbu',
        'Bobaracho',
      ],
      'Nyaribari Masaba': ['Masimba', 'Gucha', 'Kegogi', 'Gesusu'],
    },
    'Kisumu': {
      'Kisumu Central': ['Kisumu Town', 'Milimani', 'Kibuye', 'Railways'],
      'Kisumu East': ['Manyatta', 'Nyalenda', 'Kajulu', 'Kolwa'],
      'Kisumu West': ['Kisumu Town', 'Kondele', 'Obunga', 'Kibos'],
      'Muhoroni': ['Muhoroni', 'Chemelil', 'Awasi', 'Masogo'],
      'Nyakach': ['Ahero', 'Nyakach', 'Pap Onditi', 'Katito'],
      'Nyando': ['Ahero', 'Awasi', 'Kobura', 'Miwani'],
      'Seme': ['Kombewa', 'North Seme', 'Central Seme', 'East Seme'],
    },
    'Kitui': {
      'Kitui Central': ['Kitui Town', 'Kwa Vonza', 'Kisasi', 'Miambani'],
      'Kitui East': ['Zombe', 'Mutomo', 'Endau', 'Mutha'],
      'Kitui Rural': ['Kisasi', 'Kwa Mutonga', 'Chuluni', 'Kanyangi'],
      'Kitui South': ['Mutomo', 'Ikutha', 'Mutha', 'Kanziko'],
      'Kitui West': ['Kauwi', 'Mutonguni', 'Matinyani', 'Kwa Mutonga'],
      'Kyuso': ['Kyuso', 'Mumoni', 'Ngomeni', 'Tseikuru'],
      'Mwingi Central': ['Mwingi Town', 'Kanzanzu', 'Nguni', 'Kyuso'],
      'Mwingi West': ['Migwani', 'Nguutani', 'Kyuso', 'Kiomo'],
    },
    'Kwale': {
      'Kinango': ['Kinango', 'Mackinnon Road', 'Puma', 'Ndavaya'],
      'Lunga Lunga': ['Lunga Lunga', 'Vanga', 'Pongwe Kikoneni', 'Dzombo'],
      'Matuga': ['Ukunda', 'Kwale Town', 'Tiwi', 'Mkongani'],
      'Msambweni': ['Msambweni', 'Diani', 'Mkongani', 'Golini'],
    },
    'Laikipia': {
      'Laikipia Central': ['Nanyuki', 'Ngobit', 'Tigithi', 'Thingithu'],
      'Laikipia East': ['Nanyuki', 'Timau', 'Umande', 'Mugogodo'],
      'Laikipia North': ['Doldol', 'Mukogodo', 'Il Ngwesi', 'Ewaso'],
      'Laikipia West': ['Nyahururu', 'Rumuruti', 'Ol Moran', 'Sipili'],
    },
    'Lamu': {
      'Lamu East': ['Faza', 'Kiunga', 'Kizingitini', 'Pate'],
      'Lamu West': ['Lamu Town', 'Mpeketoni', 'Hindi', 'Witu'],
    },
    'Machakos': {
      'Kathiani': ['Kathiani', 'Mitaboni', 'Upper Kaewa', 'Lower Kaewa'],
      'Machakos Town': ['Machakos Town', 'Muvuti', 'Kalama', 'Mutituni'],
      'Masinga': ['Masinga', 'Kivaa', 'Ekalakala', 'Muthesya'],
      'Matungulu': ['Tala', 'Joska', 'Matungulu', 'Kyeleni'],
      'Mavoko': ['Athi River', 'Syokimau', 'Mlolongo', 'Kinanie'],
      'Mwala': ['Masii', 'Mbiuni', 'Kibauni', 'Mwala'],
      'Yatta': ['Kithimani', 'Matuu', 'Katangi', 'Ikombe'],
    },
    'Makueni': {
      'Kaiti': ['Wote', 'Kaiti', 'Kilungu', 'Mukaa'],
      'Kibwezi East': ['Makindu', 'Mtito Andei', 'Kibwezi', 'Emali'],
      'Kibwezi West': ['Kibwezi', 'Mbitini', 'Kikumbulyu', 'Nguu'],
      'Kilome': ['Kikima', 'Mukaa', 'Kasikeu', 'Kola'],
      'Makueni': ['Wote', 'Kathonzweni', 'Muvau', 'Nzaui'],
      'Mbooni': ['Tawa', 'Kithungo', 'Mbooni', 'Tulimani'],
    },
    'Mandera': {
      'Banissa': ['Banissa', 'Dandu', 'Guba', 'Malkamari'],
      'Mandera Central': ['Mandera Town', 'Rhamu', 'Ashabito', 'Takaba'],
      'Mandera East': ['El Wak', 'Rhamu', 'Shimbir Fatuma', 'Bambo'],
      'Mandera North': ['Rhamu', 'Ashabito', 'Guticha', 'Warankara'],
      'Mandera South': ['El Wak', 'Shimbir Fatuma', 'Khalalio', 'Wargadud'],
      'Lafey': ['Lafey', 'Sala', 'Fino', 'Warankara'],
    },
    'Marsabit': {
      'Laisamis': ['Laisamis', 'Korr', 'Loglogo', 'North Horr'],
      'Moyale': ['Moyale', 'Sololo', 'Heillu', 'Golbo'],
      'North Horr': ['North Horr', 'Kalacha', 'Maikona', 'Bubisa'],
      'Saku': ['Marsabit Town', 'Karare', 'Sagante', 'Marsabit'],
    },
    'Meru': {
      'Buuri East': ['Timau', 'Kisima', 'Ruiri Rwarera', 'Kiirua'],
      'Buuri West': ['Kibirichia', 'Kiirua', 'Timau', 'Kisima'],
      'Igembe Central': ['Laare', 'Maua', 'Kangeta', 'Amwathi'],
      'Igembe North': ['Antubetwe Kiongo', 'Amwathi', 'Laare', 'Mutuati'],
      'Igembe South': ['Maua', 'Kangeta', 'Athiru', 'Kiegoi'],
      'Imenti Central': ['Mitunguu', 'Abogeta', 'Mwanganthia', 'Kanyakine'],
      'Imenti North': ['Meru Town', 'Municipality', 'Ruiri', 'Timau'],
      'Imenti South': ['Nkubu', 'Mikinduri', 'Abogeta', 'Igoji'],
      'Tigania East': ['Muriri', 'Muthara', 'Mikinduri', 'Tigania'],
      'Tigania West': ['Mau', 'Athwana', 'Nkomo', 'Kianjai'],
    },
    'Migori': {
      'Awendo': ['Awendo', 'Ranen', 'Dede', 'North Sakwa'],
      'Kuria East': ['Kehancha', 'Nyabasi', 'Ntimaru', 'Kegonga'],
      'Kuria West': ['Kehancha', 'Isibania', 'Masaba', 'Tagare'],
      'Migori': ['Migori Town', 'Rongo', 'Suna', 'Nyatike'],
      'Nyatike': ['Migori', 'Macalder', 'Muhuru Bay', 'Nyatike'],
      'Rongo': ['Rongo', 'Awendo', 'Koderobara', 'South Kamagambo'],
      'Uriri': [
        'Uriri',
        'Central Kanyamkago',
        'North Kanyamkago',
        'West Kanyamkago',
      ],
    },
    'Mombasa': {
      'Changamwe': ['Changamwe', 'Port Reitz', 'Chaani', 'Airport'],
      'Jomvu': ['Jomvu Kuu', 'Mikindani', 'Miritini', 'Jomvu'],
      'Kisauni': ['Bamburi', 'Mtopanga', 'Mwakirunge', 'Shanzu'],
      'Likoni': ['Likoni', 'Timbwani', 'Bofu', 'Mtongwe'],
      'Mvita': ['Mombasa Island', 'Old Town', 'Tudor', 'Majengo'],
      'Nyali': ['Nyali', 'Kongowea', 'Frere Town', 'Mkomani'],
    },
    'Murang’a': {
      'Gatanga': ['Kakuzi', 'Gatanga', 'Ithanga', 'Muthithi'],
      'Kandara': ['Kandara', 'Muruka', 'Gaichanjiru', 'Ng’araria'],
      'Kangema': ['Kangema', 'Kanyenyaini', 'Kiharu', 'Rwathia'],
      'Kigumo': ['Kigumo', 'Kahumbu', 'Kangata', 'Muthithi'],
      'Kiharu': ['Murang’a Town', 'Kiharu', 'Mugoiri', 'Gaturi'],
      'Mathioya': ['Kiru', 'Gitugi', 'Kamacharia', 'Mathioya'],
      'Maragua': ['Maragua', 'Ichagaki', 'Makuyu', 'Kambiti'],
    },
    'Nairobi': {
      'Dagoretti North': ['Kilimani', 'Kawangware', 'Gatina', 'Riruta'],
      'Dagoretti South': ['Waithaka', 'Riruta', 'Mutuini', 'Uthiru'],
      'Embakasi Central': ['Fedha', 'Pipeline', 'Kwa Reuben', 'Kayole'],
      'Embakasi East': [
        'Utawala',
        'Mihango',
        'Upper Savannah',
        'Lower Savannah',
      ],
      'Embakasi North': ['Dandora', 'Kariobangi', 'Lucky Summer', 'Korogocho'],
      'Embakasi South': ['Imara Daima', 'Kwa Njenga', 'Kwa Reuben', 'Mukuru'],
      'Kamukunji': ['Eastleigh', 'Pangani', 'Airbase', 'California'],
      'Kasarani': ['Kasarani', 'Mwiki', 'Clay City', 'Roysambu'],
      'Kibra': ['Kibera', 'Laini Saba', 'Makina', 'Woodley'],
      'Lang’ata': ['Karen', 'South C', 'Mugumoini', 'Nairobi West'],
      'Mathare': ['Mathare', 'Huruma', 'Mlango Soko', 'Mabatini'],
      'Roysambu': ['Roysambu', 'Zimmerman', 'Kahawa', 'Githurai'],
      'Ruaraka': ['Baba Dogo', 'Lucky Summer', 'Mathare North', 'Utalii'],
      'Starehe': ['Ngara', 'Pangani', 'Nairobi CBD', 'Ziwani'],
      'Westlands': ['Parklands', 'Kangemi', 'Mountain View', 'Kitisuru'],
    },
    'Nakuru': {
      'Bahati': ['Bahati', 'Dundori', 'Kabatini', 'Wanyororo'],
      'Gilgil': ['Gilgil Town', 'Elementaita', 'Eburu', 'Morendat'],
      'Kuresoi North': ['Mau Summit', 'Amalo', 'Kuresoi', 'Nyota'],
      'Kuresoi South': ['Molo', 'Tinet', 'Kiptororo', 'Amalo'],
      'Molo': ['Molo Town', 'Elburgon', 'Turi', 'Mariashoni'],
      'Naivasha': ['Naivasha Town', 'Hell’s Gate', 'Mai Mahiu', 'Longonot'],
      'Nakuru Town East': ['Biashara', 'Flamingo', 'Kivumbini', 'Menengai'],
      'Nakuru Town West': ['London', 'Kapkures', 'Barut', 'Rhonda'],
      'Njoro': ['Njoro Town', 'Lare', 'Mau Narok', 'Nessuit'],
      'Rongai': ['Rongai', 'Solai', 'Menengai', 'Kampi ya Moto'],
      'Subukia': ['Subukia', 'Waseges', 'Kabazi', 'Sirikwa'],
    },
    'Nandi': {
      'Aldai': ['Kobujoi', 'Kaptumo', 'Kabiyet', 'Aldai'],
      'Chesumei': ['Kapsabet', 'Chemundu', 'Kiptuya', 'Nandi Hills'],
      'Emgwen': ['Kapsabet', 'Chepterwai', 'Kilibwoni', 'Kiptuiya'],
      'Mosop': ['Mosop', 'Kabiyet', 'Kipkaren', 'Kapsisiywa'],
      'Nandi Hills': ['Nandi Hills', 'Chemelil', 'Chepkumia', 'Kapkangani'],
      'Tindiret': ['Songhor', 'Tindiret', 'Kapsimotwo', 'Kamelilo'],
    },
    'Narok': {
      'Emurua Dikirr': ['Emurua Dikirr', 'Ololulunga', 'Mogondo', 'Kilgoris'],
      'Kilgoris': ['Kilgoris', 'Lolgorian', 'Angata Barikoi', 'Mogondo'],
      'Narok East': ['Narok Town', 'Mosiro', 'Suswa', 'Olokurto'],
      'Narok North': ['Narok Town', 'Nkareta', 'Olpusimoru', 'Oletukat'],
      'Narok South': ['Loita', 'Sogoo', 'Maji Moto', 'Naroosura'],
      'Narok West': ['Kilgoris', 'Transmara', 'Ololulunga', 'Ngoswani'],
      'Transmara East': [
        'Emurua Dikirr',
        'Kapsasian',
        'Ololulunga',
        'Kilgoris',
      ],
    },
    'Nyamira': {
      'Borabu': ['Nyansiongo', 'Rigoma', 'Esise', 'Manga'],
      'Manga': ['Manga', 'Kemera', 'Gesima', 'Nyamaiya'],
      'Masaba North': ['Gesima', 'Rigoma', 'Gesabakwa', 'Magombo'],
      'Nyamira North': ['Nyamira Town', 'Bosamaro', 'Bonyando', 'Kiabonyoru'],
      'Nyamira South': ['Nyamira', 'Bogichora', 'Bonyamatuta', 'Nyamaiya'],
    },
    'Nyandarua': {
      'Kinangop': ['Engineer', 'Njabini', 'Githioro', 'North Kinangop'],
      'Kipipiri': ['Wanjohi', 'Kipipiri', 'Geta', 'Githioro'],
      'Ndaragwa': ['Ndaragwa', 'Shamata', 'Leshau', 'Kiriita'],
      'Ol Kalou': ['Ol Kalou', 'Rurii', 'Kaimbaga', 'Kanjuiri Range'],
      'Ol Jorok': ['Ol Jorok', 'Gathaara', 'Gatimu', 'Charagita'],
    },
    'Nyeri': {
      'Kieni East': ['Mweiga', 'Naromoru', 'Endarasha', 'Thegu'],
      'Kieni West': ['Naro Moru', 'Mweiga', 'Mukurweini', 'Solio'],
      'Mathira': ['Karatina', 'Karatina Town', 'Iriaini', 'Kirimukuyu'],
      'Mukurweini': ['Mukurweini', 'Gikondi', 'Muhito', 'Rugi'],
      'Nyeri Town': ['Nyeri Town', 'Rware', 'Kamakwa', 'Majengo'],
      'Othaya': ['Othaya', 'Karima', 'Mahiga', 'Chinga'],
      'Tetu': ['Tetu', 'Wamagana', 'Dedan Kimathi', 'Aguthi'],
    },
    'Samburu': {
      'Samburu Central': ['Maralal', 'Loosuk', 'Suguta Marmar', 'Lodokejek'],
      'Samburu East': ['Wamba', 'Archers Post', 'Waso', 'Nyiro'],
      'Samburu North': ['Baragoi', 'South Horr', 'Lodungokwe', 'Nyiro'],
    },
    'Siaya': {
      'Bondo': ['Bondo Town', 'Usigu', 'Nyamonye', 'Maranda'],
      'Rarieda': ['Rarieda', 'Asembo', 'East Uyoma', 'West Uyoma'],
      'Gem': ['Yala', 'Nyakach', 'Central Gem', 'North Gem'],
      'Ugenya': ['Ukwala', 'Sidindi', 'East Ugenya', 'West Ugenya'],
      'Ugunja': ['Ugunja', 'Sigomre', 'Sidindi', 'West Ugenya'],
      'Alego Usonga': ['Siaya Town', 'Bondo', 'Usonga', 'Uranga'],
    },
    'Taita-Taveta': {
      'Mwatate': ['Mwatate', 'Bura', 'Chawia', 'Wundanyi'],
      'Taveta': ['Taveta', 'Voi', 'Lake Jipe', 'Kimorigo'],
      'Voi': ['Voi Town', 'Maungu', 'Mbololo', 'Kasigau'],
      'Wundanyi': ['Wundanyi', 'Mwanda', 'Werugha', 'Kishushe'],
    },
    'Tana River': {
      'Bura': ['Bura', 'Chewani', 'Hirimani', 'Sala'],
      'Galole': ['Hola', 'Garsen', 'Wayu', 'Tana Delta'],
      'Tana Delta': ['Garsen', 'Ozi', 'Kipini', 'Tana River'],
    },
    'Tharaka-Nithi': {
      'Chuka/Igamba-Ngombe': [
        'Chuka',
        'Igamba Ngombe',
        'Marimanti',
        'Magumoni',
      ],
      'Maara': ['Chogoria', 'Muthambi', 'Manga', 'Mitheru'],
      'Tharaka': ['Marimanti', 'Gatunga', 'Chiakariga', 'Tharaka'],
    },
    'Trans Nzoia': {
      'Cherangany': ['Sabaot', 'Chepchoina', 'Kwanza', 'Suwerwo'],
      'Endebess': ['Endebess', 'Chepchoina', 'Kwanza', 'Saboti'],
      'Kwanza': ['Kwanza', 'Kapomboi', 'Keiyo', 'Nabiswa'],
      'Saboti': ['Kitale', 'Saboti', 'Matisi', 'Tuwan'],
      'Kiminini': ['Kiminini', 'Sirende', 'Waitaluk', 'Hospital'],
    },
    'Turkana': {
      'Loima': ['Lokiriama', 'Lorengippi', 'Nawountos', 'Turkwel'],
      'Turkana Central': [
        'Lodwar',
        'Kerio Delta',
        'Kanamkemer',
        'Lodwar Township',
      ],
      'Turkana East': ['Lokichar', 'Kapedo', 'Katilu', 'Kainuk'],
      'Turkana North': ['Lokichoggio', 'Kakuma', 'Kalobeyei', 'Letea'],
      'Turkana South': ['Lokichar', 'Kainuk', 'Kalapata', 'Lokori'],
      'Turkana West': ['Kakuma', 'Lokichoggio', 'Kalobeyei', 'Letea'],
    },
    'Uasin Gishu': {
      'Ainabkoi': ['Eldoret East', 'Kapseret', 'Chepkoilel', 'Kaptagat'],
      'Kapsaret': ['Kapseret', 'Langas', 'Kimumu', 'Kesses'],
      'Kesses': ['Kesses', 'Cheptiret', 'Racecourse', 'Moiben'],
      'Moiben': ['Moiben', 'Sergoit', 'Karuna', 'Kimumu'],
      'Turbo': ['Turbo Town', 'Huruma', 'Kiplombe', 'Ngenyilel'],
    },
    'Vihiga': {
      'Emuhaya': ['Luanda', 'Emuhaya', 'Ebusakami', 'Kima'],
      'Hamisi': ['Hamisi', 'Shiru', 'Tambua', 'Jepkoyai'],
      'Luanda': ['Luanda Town', 'Wemilabi', 'Ebusakami', 'Mwibona'],
      'Sabatia': ['Wodanga', 'Chavakali', 'Wamuluma', 'Lyaduywa'],
      'Vihiga': ['Mbale', 'Chavakali', 'Luanda', 'Maseno'],
    },
    'Wajir': {
      'Eldas': ['Eldas', 'Lakoley South', 'Elnur', 'Tula Tula'],
      'Tarbaj': ['Tarbaj', 'Barmish', 'Sarman', 'Wajir'],
      'Wajir East': ['Wajir Town', 'Barwako', 'Khorof Harar', 'Wagberi'],
      'Wajir North': ['Batalu', 'Gurar', 'Bute', 'Khorof Harar'],
      'Wajir South': ['Habaswein', 'Diif', 'Buna', 'Wajir Bor'],
      'Wajir West': ['Griftu', 'Hadado', 'Batalu', 'Kulaaley'],
      'Wajir Central': ['Wajir Town', 'Jogbar', 'Dhanaba', 'Wagberi'],
    },
    'West Pokot': {
      'Kipkomo': ['Chepareria', 'Kasei', 'Kaptabuk', 'Lelan'],
      'Pokot South': ['Sigor', 'Chepchoina', 'Kitalakapel', 'Kasei'],
      'Pokot North': ['Alale', 'Kasei', 'Kacheliba', 'Kiwawa'],
      'Pokot Central': ['Kapenguria', 'Mnagei', 'Sook', 'Riwo'],
    },
  };

  String? _selectedCounty;
  String? _selectedSubcounty;
  String? _selectedArea;

  List<String> get _counties => _kenyaLocations.keys.toList();

  List<String> get _subcounties {
    if (_selectedCounty == null) return [];
    return _kenyaLocations[_selectedCounty!]!.keys.toList();
  }

  List<String> get _areas {
    if (_selectedCounty == null || _selectedSubcounty == null) {
      return [];
    }

    return _kenyaLocations[_selectedCounty!]![_selectedSubcounty!] ?? [];
  }

  bool _isSaving = false;

  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please turn on Location/GPS on your phone.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission was denied.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is permanently denied. Please enable it in app settings.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location captured: ${position.latitude.toStringAsFixed(6)}, '
            '${position.longitude.toStringAsFixed(6)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not get your location: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _propertyNameController.dispose();
    _unitsController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCounty == null ||
        _selectedSubcounty == null ||
        _selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select county, subcounty and area.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = OpenNestStore.supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again before adding a property.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final propertyName = _propertyNameController.text.trim();
    final location = _selectedArea!;
    final units = int.parse(_unitsController.text.trim());
    final address = _addressController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final inserted = await OpenNestStore.supabase
          .from('properties')
          .insert({
            'owner_id': user.id,
            'name': propertyName,
            'county': _selectedCounty!,
            'subcounty': _selectedSubcounty!,
            'location': location,
            'address': address,
            'latitude': _latitude,
            'longitude': _longitude,
            'description': '',
            'payment_method': 'till',
            'mpesa_till_number': '',
            'mpesa_paybill_number': '',
            'mpesa_account_number': '',
            'payments_enabled': false,
          })
          .select()
          .single();

      await OpenNestStore.loadPropertiesFromSupabase();

      final propertyId = inserted['id']?.toString() ?? '';

      if (propertyId.isNotEmpty) {
        for (int i = 1; i <= units; i++) {
          OpenNestStore.apartments.add(
            Apartment(
              id: '${propertyId}_unit_$i',
              propertyId: propertyId,
              propertyName: propertyName,
              number: i.toString(),
              type: 'Apartment',
              rent: '0',
              status: 'Vacant',
              location: location,
              description: '',
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Property added successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add property: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Property',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B3D2E), Color(0xFF126B4F)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.apartment_rounded, color: Colors.white, size: 36),
                  SizedBox(height: 14),
                  Text(
                    'Add another property',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'This property will be connected to your current owner account.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Property Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3D2E),
              ),
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: _propertyNameController,
              decoration: const InputDecoration(
                labelText: 'Property / Apartment Name',
                hintText: 'e.g. Green Valley Apartments',
                prefixIcon: Icon(Icons.home_work_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the property name';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _selectedCounty,
              decoration: const InputDecoration(
                labelText: 'County',
                prefixIcon: Icon(Icons.map_outlined),
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select county'),
              items: _counties.map((county) {
                return DropdownMenuItem<String>(
                  value: county,
                  child: Text(county),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCounty = value;
                  _selectedSubcounty = null;
                  _selectedArea = null;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Select a county';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _selectedSubcounty,
              decoration: const InputDecoration(
                labelText: 'Subcounty',
                prefixIcon: Icon(Icons.location_city_outlined),
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select subcounty'),
              items: _subcounties.map((subcounty) {
                return DropdownMenuItem<String>(
                  value: subcounty,
                  child: Text(subcounty),
                );
              }).toList(),
              onChanged: _selectedCounty == null
                  ? null
                  : (value) {
                      setState(() {
                        _selectedSubcounty = value;
                        _selectedArea = null;
                      });
                    },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Select a subcounty';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _selectedArea,
              decoration: const InputDecoration(
                labelText: 'Area',
                prefixIcon: Icon(Icons.place_outlined),
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select area'),
              items: _areas.map((area) {
                return DropdownMenuItem<String>(value: area, child: Text(area));
              }).toList(),
              onChanged: _selectedSubcounty == null
                  ? null
                  : (value) {
                      setState(() {
                        _selectedArea = value;
                      });
                    },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Select an area';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: _unitsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of Units',
                hintText: 'e.g. 24',
                prefixIcon: Icon(Icons.grid_view_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter number of units';
                }

                final number = int.tryParse(value.trim());

                if (number == null || number < 1) {
                  return 'Enter a valid number of units';
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Property Address',
                hintText: 'Enter the full address',
                prefixIcon: Icon(Icons.map_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the property address';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: _isGettingLocation ? null : _getCurrentLocation,
              icon: _isGettingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _isGettingLocation
                    ? 'Getting Current Location...'
                    : _latitude == null
                    ? 'Use My Current Location'
                    : 'Location Captured',
              ),
            ),

            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.green.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'GPS location captured\n'
                        '${_latitude!.toStringAsFixed(6)}, '
                        '${_longitude!.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveProperty,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving Property...' : 'Save Property'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// JUMAA - REGISTER APARTMENT / OWNER ACCOUNT
// ============================================================

class RegisterApartmentPage extends StatefulWidget {
  const RegisterApartmentPage({super.key});

  @override
  State<RegisterApartmentPage> createState() => _RegisterApartmentPageState();
}

class _RegisterApartmentPageState extends State<RegisterApartmentPage> {
  final _formKey = GlobalKey<FormState>();

  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _propertyNameController = TextEditingController();
  final _unitsController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedCounty;
  String? _selectedSubcounty;
  String? _selectedArea;

  static const Map<String, Map<String, List<String>>> _kenyaLocations = {
    'Baringo': {
      'Baringo Central': ['Kabarnet', 'Sacho', 'Ewalel', 'Tenges'],
      'Baringo North': ['Kabartonjo', 'Barwessa', 'Sibilo', 'Bartabwa'],
      'East Pokot': ['Chepchoina', 'Chemolingot', 'Kolloa', 'Churo'],
      'Mogotio': ['Mogotio', 'Emining', 'Lembus', 'Solian'],
      'Marigat': ['Marigat', 'Ilchamus', 'Mochongoi', 'Nginyang'],
      'Tiaty': ['Chemolingot', 'Churo', 'Tangulbei', 'Silale'],
    },
    'Bomet': {
      'Bomet Central': ['Bomet Town', 'Longisa', 'Mutarakwa', 'Silibwet'],
      'Bomet East': ['Kaplong', 'Chebunyo', 'Koiwa', 'Merigi'],
      'Chepalungu': ['Sigor', 'Siongiroi', 'Chebunyo', 'Kongasis'],
      'Konoin': ['Chebunyo', 'Mogogosiek', 'Boito', 'Kimulot'],
      'Sotik': ['Sotik Town', 'Chemagel', 'Ndanai', 'Kaplong'],
    },
    'Bungoma': {
      'Bumula': ['Bumula', 'Khasoko', 'Siboti', 'South Bukusu'],
      'Bungoma Central': ['Bungoma Town', 'Kanduyi', 'Township', 'Musikoma'],
      'Bungoma East': ['Chwele', 'Ndivisi', 'Kabuchai', 'Mukuyuni'],
      'Bungoma North': ['Tongaren', 'Naitiri', 'Mbakalo', 'Mukhweya'],
      'Bungoma South': ['Webuye', 'Misikhu', 'Lugari', 'Matete'],
      'Kimilili': ['Kimilili', 'Maeni', 'Kibingei', 'Kamukuywa'],
      'Mt Elgon': ['Kapsokwony', 'Cheptais', 'Kaptama', 'Kaptoboi'],
    },
    'Busia': {
      'Bunyala': ['Bunyala', 'Budalangi', 'Port Victoria', 'Namboboto'],
      'Butula': ['Butula', 'Kingandole', 'Elugulu', 'Marachi'],
      'Samia': ['Funyula', 'Agenga', 'Nangina', 'Namboboto'],
      'Teso North': ['Amagoro', 'Malaba', 'Angurai', 'Malakisi'],
      'Teso South': ['Amukura', 'Angorom', 'Asinge', 'Angorom'],
      'Matayos': ['Matayos', 'Busia Town', 'Burumba', 'Mayenje'],
    },
    'Elgeyo-Marakwet': {
      'Keiyo North': ['Iten', 'Kapsowar', 'Kaptarakwa', 'Chepkorio'],
      'Keiyo South': ['Chepkorio', 'Kaptagat', 'Kamariny', 'Metkei'],
      'Marakwet East': ['Kapyego', 'Kapsowar', 'Arror', 'Tot'],
      'Marakwet West': ['Kapsowar', 'Cheptongei', 'Lelan', 'Kapsait'],
    },
    'Embu': {
      'Manyatta': ['Embu Town', 'Kithimu', 'Nginda', 'Gichiche'],
      'Mbeere North': ['Siakago', 'Nthawa', 'Muminji', 'Evurore'],
      'Mbeere South': ['Kiritiri', 'Gachoka', 'Ishiara', 'Makima'],
      'Runyenjes': ['Runyenjes', 'Kagaari', 'Kyeni', 'Gichiche'],
    },
    'Garissa': {
      'Daadab': ['Daadab', 'Liboi', 'Damajale', 'Abakaile'],
      'Fafi': ['Bura', 'Jarajila', 'Fafi', 'Bura East'],
      'Garissa Township': ['Garissa Town', 'Waberi', 'Galbet', 'Township'],
      'Hulugho': ['Hulugho', 'Sangailu', 'Bura'],
      'Ijara': ['Masalani', 'Ijara', 'Kotile', 'Sangailu'],
      'Lagdera': ['Modogashe', 'Benane', 'Baraki', 'Goreale'],
    },
    'Homa Bay': {
      'Homa Bay Town': ['Homa Bay Town', 'Asego', 'Kanyabala', 'Kojwach'],
      'Kabondo Kasipul': ['Kabondo', 'Kasipul', 'Kokwanyo', 'Kojwach'],
      'Karachuonyo': ['Kendu Bay', 'Wangchieng', 'Kibiri', 'Central'],
      'Kasipul': ['Oyugis', 'Kojwach', 'Kokoth Kat', 'Kabondo'],
      'Mbita': ['Mbita Town', 'Rusinga', 'Mfangano', 'Lambwe'],
      'Ndhiwa': ['Ndhiwa', 'Kandiege', 'Kochia', 'Kabuoch'],
      'Suba': ['Sori', 'Gwassi', 'Kaksingri', 'Magunga'],
    },
    'Isiolo': {
      'Isiolo Central': ['Isiolo Town', 'Burat', 'Ngaremara', 'Bulapesa'],
      'Isiolo North': ['Merti', 'Kinna', 'Oldonyiro', 'Sericho'],
    },
    'Kajiado': {
      'Kajiado Central': ['Kajiado Town', 'Purko', 'Elangata Wuas', 'Namanga'],
      'Kajiado North': ['Ngong', 'Oloolua', 'Olkeri', 'Nkaimurunya'],
      'Kajiado South': ['Loitokitok', 'Kimana', 'Entonet', 'Rombo'],
      'Kajiado East': ['Kitengela', 'Kaputiei', 'Imaroro', 'Kajiado'],
      'Kajiado West': ['Magadi', 'Ewuaso Kedong', 'Ilmarba', 'Keek Onke'],
    },
    'Kakamega': {
      'Butere': ['Butere', 'Marama', 'Shirere', 'Shitoto'],
      'Kakamega Central': ['Kakamega Town', 'Shieywe', 'Bukhungu', 'Lurambi'],
      'Kakamega East': ['Shinyalu', 'Isukha', 'Murhanda', 'Shirere'],
      'Kakamega North': ['Malava', 'Butali', 'Chemuche', 'Shirere'],
      'Kakamega South': ['Khwisero', 'Mumias', 'Shinyalu', 'Lurambi'],
      'Lugari': ['Lugari', 'Mautuma', 'Lumakanda', 'Matete'],
      'Matungu': ['Matungu', 'Koyonzo', 'Kholera', 'Mayoni'],
      'Mumias East': ['Mumias', 'Lubinu', 'Lubao', 'Namamali'],
    },
    'Kericho': {
      'Ainamoi': ['Kericho Town', 'Kapkugerwet', 'Kipchebor', 'Chepseon'],
      'Belgut': ['Sosiot', 'Kabianga', 'Kapkugerwet', 'Chepseon'],
      'Bureti': ['Litein', 'Cheborge', 'Kapkatet', 'Chebunyo'],
      'Kipkelion East': ['Londiani', 'Tendeno', 'Kedowa', 'Kipkelion'],
      'Kipkelion West': ['Kipkelion', 'Kunyak', 'Kamasian', 'Chilchila'],
      'Soin Sigowet': ['Sigowet', 'Soin', 'Soliat', 'Kapkugerwet'],
    },
    'Kiambu': {
      'Gatundu North': ['Gatundu', 'Kiamwangi', 'Kanjuku', 'Githobokoni'],
      'Gatundu South': ['Gatundu South', 'Kiamwangi', 'Ngenda', 'Kiganjo'],
      'Githunguri': ['Githunguri', 'Ikinu', 'Githiga', 'Kiairia'],
      'Juja': ['Juja', 'Kalimoni', 'Murera', 'Theta'],
      'Kabete': ['Kabete', 'Uthiru', 'Wangige', 'Gitaru'],
      'Kiambaa': ['Kiambu', 'Karuri', 'Muchatha', 'Ciiko'],
      'Kiambu Town': ['Kiambu Town', 'Tinganga', 'Ndumberi', 'Ruaka'],
      'Kikuyu': ['Kikuyu', 'Zambezi', 'Karai', 'Nachu'],
      'Limuru': ['Limuru', 'Tigoni', 'Ndeiya', 'Bibirioni'],
      'Ruiru': ['Ruiru', 'Kahawa', 'Githurai', 'Kimbo'],
      'Thika Town': ['Thika Town', 'Makongeni', 'Section 9', 'Gatuanyaga'],
      'Lari': ['Lari', 'Kijabe', 'Kinale', 'Nyanduma'],
    },
    'Kilifi': {
      'Kilifi North': ['Kilifi Town', 'Tezo', 'Mnarani', 'Sokoni'],
      'Kilifi South': ['Shimo la Tewa', 'Mtwapa', 'Chasimba', 'Mtepeni'],
      'Kaloleni': ['Kaloleni', 'Mariakani', 'Mwanamwinga', 'Kayafungo'],
      'Rabai': ['Rabai', 'Ruruma', 'Mwawesa', 'Kambe'],
      'Ganze': ['Ganze', 'Bamba', 'Jaribuni', 'Vitengeni'],
      'Malindi': ['Malindi Town', 'Ganda', 'Shela', 'Watamu'],
      'Magarini': ['Marafa', 'Gongoni', 'Adu', 'Garashi'],
    },
    'Kirinyaga': {
      'Kirinyaga Central': ['Kerugoya', 'Kutus', 'Kibirigwi', 'Mutira'],
      'Kirinyaga East': ['Kagio', 'Kutus', 'Njukiini', 'Kanyekini'],
      'Kirinyaga West': ['Baricho', 'Kiamaina', 'Kibirigwi', 'Ndia'],
      'Mwea East': ['Wanguru', 'Makutano', 'Kangai', 'Murinduko'],
      'Mwea West': ['Kagio', 'Kutus', 'Wamumu', 'Thiba'],
    },
    'Kisii': {
      'Bobasi': ['Ogembo', 'Nyamache', 'Masige', 'Bobasi'],
      'Bomachoge Borabu': ['Etago', 'Nyamache', 'Moticho', 'Boochi'],
      'Bomachoge Chache': ['Kisii Town', 'Mosocho', 'Masige', 'Boochi'],
      'Bonchari': ['Riana', 'Bobaracho', 'Mariba', 'Bonyando'],
      'Kitutu Chache North': ['Kisii Town', 'Keumbu', 'Sensi', 'Birongo'],
      'Kitutu Chache South': ['Masaba', 'Nyatieko', 'Bogeka', 'Mosocho'],
      'Nyaribari Chache': [
        'Kisii Town',
        'Kisii Central',
        'Keumbu',
        'Bobaracho',
      ],
      'Nyaribari Masaba': ['Masimba', 'Gucha', 'Kegogi', 'Gesusu'],
    },
    'Kisumu': {
      'Kisumu Central': ['Kisumu Town', 'Milimani', 'Kibuye', 'Railways'],
      'Kisumu East': ['Manyatta', 'Nyalenda', 'Kajulu', 'Kolwa'],
      'Kisumu West': ['Kisumu Town', 'Kondele', 'Obunga', 'Kibos'],
      'Muhoroni': ['Muhoroni', 'Chemelil', 'Awasi', 'Masogo'],
      'Nyakach': ['Ahero', 'Nyakach', 'Pap Onditi', 'Katito'],
      'Nyando': ['Ahero', 'Awasi', 'Kobura', 'Miwani'],
      'Seme': ['Kombewa', 'North Seme', 'Central Seme', 'East Seme'],
    },
    'Kitui': {
      'Kitui Central': ['Kitui Town', 'Kwa Vonza', 'Kisasi', 'Miambani'],
      'Kitui East': ['Zombe', 'Mutomo', 'Endau', 'Mutha'],
      'Kitui Rural': ['Kisasi', 'Kwa Mutonga', 'Chuluni', 'Kanyangi'],
      'Kitui South': ['Mutomo', 'Ikutha', 'Mutha', 'Kanziko'],
      'Kitui West': ['Kauwi', 'Mutonguni', 'Matinyani', 'Kwa Mutonga'],
      'Kyuso': ['Kyuso', 'Mumoni', 'Ngomeni', 'Tseikuru'],
      'Mwingi Central': ['Mwingi Town', 'Kanzanzu', 'Nguni', 'Kyuso'],
      'Mwingi West': ['Migwani', 'Nguutani', 'Kyuso', 'Kiomo'],
    },
    'Kwale': {
      'Kinango': ['Kinango', 'Mackinnon Road', 'Puma', 'Ndavaya'],
      'Lunga Lunga': ['Lunga Lunga', 'Vanga', 'Pongwe Kikoneni', 'Dzombo'],
      'Matuga': ['Ukunda', 'Kwale Town', 'Tiwi', 'Mkongani'],
      'Msambweni': ['Msambweni', 'Diani', 'Mkongani', 'Golini'],
    },
    'Laikipia': {
      'Laikipia Central': ['Nanyuki', 'Ngobit', 'Tigithi', 'Thingithu'],
      'Laikipia East': ['Nanyuki', 'Timau', 'Umande', 'Mugogodo'],
      'Laikipia North': ['Doldol', 'Mukogodo', 'Il Ngwesi', 'Ewaso'],
      'Laikipia West': ['Nyahururu', 'Rumuruti', 'Ol Moran', 'Sipili'],
    },
    'Lamu': {
      'Lamu East': ['Faza', 'Kiunga', 'Kizingitini', 'Pate'],
      'Lamu West': ['Lamu Town', 'Mpeketoni', 'Hindi', 'Witu'],
    },
    'Machakos': {
      'Kathiani': ['Kathiani', 'Mitaboni', 'Upper Kaewa', 'Lower Kaewa'],
      'Machakos Town': ['Machakos Town', 'Muvuti', 'Kalama', 'Mutituni'],
      'Masinga': ['Masinga', 'Kivaa', 'Ekalakala', 'Muthesya'],
      'Matungulu': ['Tala', 'Joska', 'Matungulu', 'Kyeleni'],
      'Mavoko': ['Athi River', 'Syokimau', 'Mlolongo', 'Kinanie'],
      'Mwala': ['Masii', 'Mbiuni', 'Kibauni', 'Mwala'],
      'Yatta': ['Kithimani', 'Matuu', 'Katangi', 'Ikombe'],
    },
    'Makueni': {
      'Kaiti': ['Wote', 'Kaiti', 'Kilungu', 'Mukaa'],
      'Kibwezi East': ['Makindu', 'Mtito Andei', 'Kibwezi', 'Emali'],
      'Kibwezi West': ['Kibwezi', 'Mbitini', 'Kikumbulyu', 'Nguu'],
      'Kilome': ['Kikima', 'Mukaa', 'Kasikeu', 'Kola'],
      'Makueni': ['Wote', 'Kathonzweni', 'Muvau', 'Nzaui'],
      'Mbooni': ['Tawa', 'Kithungo', 'Mbooni', 'Tulimani'],
    },
    'Mandera': {
      'Banissa': ['Banissa', 'Dandu', 'Guba', 'Malkamari'],
      'Mandera Central': ['Mandera Town', 'Rhamu', 'Ashabito', 'Takaba'],
      'Mandera East': ['El Wak', 'Rhamu', 'Shimbir Fatuma', 'Bambo'],
      'Mandera North': ['Rhamu', 'Ashabito', 'Guticha', 'Warankara'],
      'Mandera South': ['El Wak', 'Shimbir Fatuma', 'Khalalio', 'Wargadud'],
      'Lafey': ['Lafey', 'Sala', 'Fino', 'Warankara'],
    },
    'Marsabit': {
      'Laisamis': ['Laisamis', 'Korr', 'Loglogo', 'North Horr'],
      'Moyale': ['Moyale', 'Sololo', 'Heillu', 'Golbo'],
      'North Horr': ['North Horr', 'Kalacha', 'Maikona', 'Bubisa'],
      'Saku': ['Marsabit Town', 'Karare', 'Sagante', 'Marsabit'],
    },
    'Meru': {
      'Buuri East': ['Timau', 'Kisima', 'Ruiri Rwarera', 'Kiirua'],
      'Buuri West': ['Kibirichia', 'Kiirua', 'Timau', 'Kisima'],
      'Igembe Central': ['Laare', 'Maua', 'Kangeta', 'Amwathi'],
      'Igembe North': ['Antubetwe Kiongo', 'Amwathi', 'Laare', 'Mutuati'],
      'Igembe South': ['Maua', 'Kangeta', 'Athiru', 'Kiegoi'],
      'Imenti Central': ['Mitunguu', 'Abogeta', 'Mwanganthia', 'Kanyakine'],
      'Imenti North': ['Meru Town', 'Municipality', 'Ruiri', 'Timau'],
      'Imenti South': ['Nkubu', 'Mikinduri', 'Abogeta', 'Igoji'],
      'Tigania East': ['Muriri', 'Muthara', 'Mikinduri', 'Tigania'],
      'Tigania West': ['Mau', 'Athwana', 'Nkomo', 'Kianjai'],
    },
    'Migori': {
      'Awendo': ['Awendo', 'Ranen', 'Dede', 'North Sakwa'],
      'Kuria East': ['Kehancha', 'Nyabasi', 'Ntimaru', 'Kegonga'],
      'Kuria West': ['Kehancha', 'Isibania', 'Masaba', 'Tagare'],
      'Migori': ['Migori Town', 'Rongo', 'Suna', 'Nyatike'],
      'Nyatike': ['Migori', 'Macalder', 'Muhuru Bay', 'Nyatike'],
      'Rongo': ['Rongo', 'Awendo', 'Koderobara', 'South Kamagambo'],
      'Uriri': [
        'Uriri',
        'Central Kanyamkago',
        'North Kanyamkago',
        'West Kanyamkago',
      ],
    },
    'Mombasa': {
      'Changamwe': ['Changamwe', 'Port Reitz', 'Chaani', 'Airport'],
      'Jomvu': ['Jomvu Kuu', 'Mikindani', 'Miritini', 'Jomvu'],
      'Kisauni': ['Bamburi', 'Mtopanga', 'Mwakirunge', 'Shanzu'],
      'Likoni': ['Likoni', 'Timbwani', 'Bofu', 'Mtongwe'],
      'Mvita': ['Mombasa Island', 'Old Town', 'Tudor', 'Majengo'],
      'Nyali': ['Nyali', 'Kongowea', 'Frere Town', 'Mkomani'],
    },
    'Murang’a': {
      'Gatanga': ['Kakuzi', 'Gatanga', 'Ithanga', 'Muthithi'],
      'Kandara': ['Kandara', 'Muruka', 'Gaichanjiru', 'Ng’araria'],
      'Kangema': ['Kangema', 'Kanyenyaini', 'Kiharu', 'Rwathia'],
      'Kigumo': ['Kigumo', 'Kahumbu', 'Kangata', 'Muthithi'],
      'Kiharu': ['Murang’a Town', 'Kiharu', 'Mugoiri', 'Gaturi'],
      'Mathioya': ['Kiru', 'Gitugi', 'Kamacharia', 'Mathioya'],
      'Maragua': ['Maragua', 'Ichagaki', 'Makuyu', 'Kambiti'],
    },
    'Nairobi': {
      'Dagoretti North': ['Kilimani', 'Kawangware', 'Gatina', 'Riruta'],
      'Dagoretti South': ['Waithaka', 'Riruta', 'Mutuini', 'Uthiru'],
      'Embakasi Central': ['Fedha', 'Pipeline', 'Kwa Reuben', 'Kayole'],
      'Embakasi East': [
        'Utawala',
        'Mihango',
        'Upper Savannah',
        'Lower Savannah',
      ],
      'Embakasi North': ['Dandora', 'Kariobangi', 'Lucky Summer', 'Korogocho'],
      'Embakasi South': ['Imara Daima', 'Kwa Njenga', 'Kwa Reuben', 'Mukuru'],
      'Kamukunji': ['Eastleigh', 'Pangani', 'Airbase', 'California'],
      'Kasarani': ['Kasarani', 'Mwiki', 'Clay City', 'Roysambu'],
      'Kibra': ['Kibera', 'Laini Saba', 'Makina', 'Woodley'],
      'Lang’ata': ['Karen', 'South C', 'Mugumoini', 'Nairobi West'],
      'Mathare': ['Mathare', 'Huruma', 'Mlango Soko', 'Mabatini'],
      'Roysambu': ['Roysambu', 'Zimmerman', 'Kahawa', 'Githurai'],
      'Ruaraka': ['Baba Dogo', 'Lucky Summer', 'Mathare North', 'Utalii'],
      'Starehe': ['Ngara', 'Pangani', 'Nairobi CBD', 'Ziwani'],
      'Westlands': ['Parklands', 'Kangemi', 'Mountain View', 'Kitisuru'],
    },
    'Nakuru': {
      'Bahati': ['Bahati', 'Dundori', 'Kabatini', 'Wanyororo'],
      'Gilgil': ['Gilgil Town', 'Elementaita', 'Eburu', 'Morendat'],
      'Kuresoi North': ['Mau Summit', 'Amalo', 'Kuresoi', 'Nyota'],
      'Kuresoi South': ['Molo', 'Tinet', 'Kiptororo', 'Amalo'],
      'Molo': ['Molo Town', 'Elburgon', 'Turi', 'Mariashoni'],
      'Naivasha': ['Naivasha Town', 'Hell’s Gate', 'Mai Mahiu', 'Longonot'],
      'Nakuru Town East': ['Biashara', 'Flamingo', 'Kivumbini', 'Menengai'],
      'Nakuru Town West': ['London', 'Kapkures', 'Barut', 'Rhonda'],
      'Njoro': ['Njoro Town', 'Lare', 'Mau Narok', 'Nessuit'],
      'Rongai': ['Rongai', 'Solai', 'Menengai', 'Kampi ya Moto'],
      'Subukia': ['Subukia', 'Waseges', 'Kabazi', 'Sirikwa'],
    },
    'Nandi': {
      'Aldai': ['Kobujoi', 'Kaptumo', 'Kabiyet', 'Aldai'],
      'Chesumei': ['Kapsabet', 'Chemundu', 'Kiptuya', 'Nandi Hills'],
      'Emgwen': ['Kapsabet', 'Chepterwai', 'Kilibwoni', 'Kiptuiya'],
      'Mosop': ['Mosop', 'Kabiyet', 'Kipkaren', 'Kapsisiywa'],
      'Nandi Hills': ['Nandi Hills', 'Chemelil', 'Chepkumia', 'Kapkangani'],
      'Tindiret': ['Songhor', 'Tindiret', 'Kapsimotwo', 'Kamelilo'],
    },
    'Narok': {
      'Emurua Dikirr': ['Emurua Dikirr', 'Ololulunga', 'Mogondo', 'Kilgoris'],
      'Kilgoris': ['Kilgoris', 'Lolgorian', 'Angata Barikoi', 'Mogondo'],
      'Narok East': ['Narok Town', 'Mosiro', 'Suswa', 'Olokurto'],
      'Narok North': ['Narok Town', 'Nkareta', 'Olpusimoru', 'Oletukat'],
      'Narok South': ['Loita', 'Sogoo', 'Maji Moto', 'Naroosura'],
      'Narok West': ['Kilgoris', 'Transmara', 'Ololulunga', 'Ngoswani'],
      'Transmara East': [
        'Emurua Dikirr',
        'Kapsasian',
        'Ololulunga',
        'Kilgoris',
      ],
    },
    'Nyamira': {
      'Borabu': ['Nyansiongo', 'Rigoma', 'Esise', 'Manga'],
      'Manga': ['Manga', 'Kemera', 'Gesima', 'Nyamaiya'],
      'Masaba North': ['Gesima', 'Rigoma', 'Gesabakwa', 'Magombo'],
      'Nyamira North': ['Nyamira Town', 'Bosamaro', 'Bonyando', 'Kiabonyoru'],
      'Nyamira South': ['Nyamira', 'Bogichora', 'Bonyamatuta', 'Nyamaiya'],
    },
    'Nyandarua': {
      'Kinangop': ['Engineer', 'Njabini', 'Githioro', 'North Kinangop'],
      'Kipipiri': ['Wanjohi', 'Kipipiri', 'Geta', 'Githioro'],
      'Ndaragwa': ['Ndaragwa', 'Shamata', 'Leshau', 'Kiriita'],
      'Ol Kalou': ['Ol Kalou', 'Rurii', 'Kaimbaga', 'Kanjuiri Range'],
      'Ol Jorok': ['Ol Jorok', 'Gathaara', 'Gatimu', 'Charagita'],
    },
    'Nyeri': {
      'Kieni East': ['Mweiga', 'Naromoru', 'Endarasha', 'Thegu'],
      'Kieni West': ['Naro Moru', 'Mweiga', 'Mukurweini', 'Solio'],
      'Mathira': ['Karatina', 'Karatina Town', 'Iriaini', 'Kirimukuyu'],
      'Mukurweini': ['Mukurweini', 'Gikondi', 'Muhito', 'Rugi'],
      'Nyeri Town': ['Nyeri Town', 'Rware', 'Kamakwa', 'Majengo'],
      'Othaya': ['Othaya', 'Karima', 'Mahiga', 'Chinga'],
      'Tetu': ['Tetu', 'Wamagana', 'Dedan Kimathi', 'Aguthi'],
    },
    'Samburu': {
      'Samburu Central': ['Maralal', 'Loosuk', 'Suguta Marmar', 'Lodokejek'],
      'Samburu East': ['Wamba', 'Archers Post', 'Waso', 'Nyiro'],
      'Samburu North': ['Baragoi', 'South Horr', 'Lodungokwe', 'Nyiro'],
    },
    'Siaya': {
      'Bondo': ['Bondo Town', 'Usigu', 'Nyamonye', 'Maranda'],
      'Rarieda': ['Rarieda', 'Asembo', 'East Uyoma', 'West Uyoma'],
      'Gem': ['Yala', 'Nyakach', 'Central Gem', 'North Gem'],
      'Ugenya': ['Ukwala', 'Sidindi', 'East Ugenya', 'West Ugenya'],
      'Ugunja': ['Ugunja', 'Sigomre', 'Sidindi', 'West Ugenya'],
      'Alego Usonga': ['Siaya Town', 'Bondo', 'Usonga', 'Uranga'],
    },
    'Taita-Taveta': {
      'Mwatate': ['Mwatate', 'Bura', 'Chawia', 'Wundanyi'],
      'Taveta': ['Taveta', 'Voi', 'Lake Jipe', 'Kimorigo'],
      'Voi': ['Voi Town', 'Maungu', 'Mbololo', 'Kasigau'],
      'Wundanyi': ['Wundanyi', 'Mwanda', 'Werugha', 'Kishushe'],
    },
    'Tana River': {
      'Bura': ['Bura', 'Chewani', 'Hirimani', 'Sala'],
      'Galole': ['Hola', 'Garsen', 'Wayu', 'Tana Delta'],
      'Tana Delta': ['Garsen', 'Ozi', 'Kipini', 'Tana River'],
    },
    'Tharaka-Nithi': {
      'Chuka/Igamba-Ngombe': [
        'Chuka',
        'Igamba Ngombe',
        'Marimanti',
        'Magumoni',
      ],
      'Maara': ['Chogoria', 'Muthambi', 'Manga', 'Mitheru'],
      'Tharaka': ['Marimanti', 'Gatunga', 'Chiakariga', 'Tharaka'],
    },
    'Trans Nzoia': {
      'Cherangany': ['Sabaot', 'Chepchoina', 'Kwanza', 'Suwerwo'],
      'Endebess': ['Endebess', 'Chepchoina', 'Kwanza', 'Saboti'],
      'Kwanza': ['Kwanza', 'Kapomboi', 'Keiyo', 'Nabiswa'],
      'Saboti': ['Kitale', 'Saboti', 'Matisi', 'Tuwan'],
      'Kiminini': ['Kiminini', 'Sirende', 'Waitaluk', 'Hospital'],
    },
    'Turkana': {
      'Loima': ['Lokiriama', 'Lorengippi', 'Nawountos', 'Turkwel'],
      'Turkana Central': [
        'Lodwar',
        'Kerio Delta',
        'Kanamkemer',
        'Lodwar Township',
      ],
      'Turkana East': ['Lokichar', 'Kapedo', 'Katilu', 'Kainuk'],
      'Turkana North': ['Lokichoggio', 'Kakuma', 'Kalobeyei', 'Letea'],
      'Turkana South': ['Lokichar', 'Kainuk', 'Kalapata', 'Lokori'],
      'Turkana West': ['Kakuma', 'Lokichoggio', 'Kalobeyei', 'Letea'],
    },
    'Uasin Gishu': {
      'Ainabkoi': ['Eldoret East', 'Kapseret', 'Chepkoilel', 'Kaptagat'],
      'Kapsaret': ['Kapseret', 'Langas', 'Kimumu', 'Kesses'],
      'Kesses': ['Kesses', 'Cheptiret', 'Racecourse', 'Moiben'],
      'Moiben': ['Moiben', 'Sergoit', 'Karuna', 'Kimumu'],
      'Turbo': ['Turbo Town', 'Huruma', 'Kiplombe', 'Ngenyilel'],
    },
    'Vihiga': {
      'Emuhaya': ['Luanda', 'Emuhaya', 'Ebusakami', 'Kima'],
      'Hamisi': ['Hamisi', 'Shiru', 'Tambua', 'Jepkoyai'],
      'Luanda': ['Luanda Town', 'Wemilabi', 'Ebusakami', 'Mwibona'],
      'Sabatia': ['Wodanga', 'Chavakali', 'Wamuluma', 'Lyaduywa'],
      'Vihiga': ['Mbale', 'Chavakali', 'Luanda', 'Maseno'],
    },
    'Wajir': {
      'Eldas': ['Eldas', 'Lakoley South', 'Elnur', 'Tula Tula'],
      'Tarbaj': ['Tarbaj', 'Barmish', 'Sarman', 'Wajir'],
      'Wajir East': ['Wajir Town', 'Barwako', 'Khorof Harar', 'Wagberi'],
      'Wajir North': ['Batalu', 'Gurar', 'Bute', 'Khorof Harar'],
      'Wajir South': ['Habaswein', 'Diif', 'Buna', 'Wajir Bor'],
      'Wajir West': ['Griftu', 'Hadado', 'Batalu', 'Kulaaley'],
      'Wajir Central': ['Wajir Town', 'Jogbar', 'Dhanaba', 'Wagberi'],
    },
    'West Pokot': {
      'Kipkomo': ['Chepareria', 'Kasei', 'Kaptabuk', 'Lelan'],
      'Pokot South': ['Sigor', 'Chepchoina', 'Kitalakapel', 'Kasei'],
      'Pokot North': ['Alale', 'Kasei', 'Kacheliba', 'Kiwawa'],
      'Pokot Central': ['Kapenguria', 'Mnagei', 'Sook', 'Riwo'],
    },
  };

  List<String> get _counties => _kenyaLocations.keys.toList();

  List<String> get _subcounties {
    if (_selectedCounty == null) return [];
    return _kenyaLocations[_selectedCounty!]!.keys.toList();
  }

  List<String> get _areas {
    if (_selectedCounty == null || _selectedSubcounty == null) {
      return [];
    }

    return _kenyaLocations[_selectedCounty!]![_selectedSubcounty!] ?? [];
  }

  bool _obscurePassword = true;
  bool _isCreating = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _propertyNameController.dispose();
    _unitsController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _createOwnerAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms & Conditions to continue.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ownerName = _ownerNameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    final propertyName = _propertyNameController.text.trim();
    final location = _selectedArea!;
    final address = _addressController.text.trim();

    setState(() {
      _isCreating = true;
    });

    try {
      // ----------------------------------------------------------
      // 1. Create the Supabase Auth account.
      // ----------------------------------------------------------
      final authResponse = await OpenNestStore.supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': ownerName, 'phone': phone, 'role': 'owner'},
      );

      final user = authResponse.user;

      if (user == null) {
        throw Exception(
          'Supabase did not return a user. Check your Supabase Auth settings.',
        );
      }

      debugPrint('SIGNUP DEBUG: user=${user.id}');
      debugPrint('SIGNUP DEBUG: session=${authResponse.session != null}');
      debugPrint('SIGNUP DEBUG: emailConfirmedAt=${user.emailConfirmedAt}');

      if (authResponse.session == null) {
        throw Exception(
          'ACCOUNT CREATED BUT EMAIL VERIFICATION IS REQUIRED. '
          'Check your email to verify the account, then log in.',
        );
      }

      debugPrint('REGISTRATION STEP 1: Auth successful');

      // Create the owner profile while authenticated.
      await OpenNestStore.supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': ownerName,
        'email': email,
        'phone': phone,
        'role': 'owner',
      });

      debugPrint('REGISTRATION STEP 2: Profile created');

      // ----------------------------------------------------------
      // 2. Create the property belonging to this owner.
      // ----------------------------------------------------------
      debugPrint('PROPERTY INSERT: START');

      final insertedProperty = await OpenNestStore.supabase
          .from('properties')
          .insert({
            'owner_id': user.id,
            'name': propertyName,
            'county': _selectedCounty!,
            'subcounty': _selectedSubcounty!,
            'location': location,
            'address': address,
            'description': '',
            'payment_method': 'till',
            'mpesa_till_number': '',
            'mpesa_paybill_number': '',
            'mpesa_account_number': '',
            'payments_enabled': false,
          })
          .select()
          .single();

      debugPrint('PROPERTY INSERT: SUCCESS');
      debugPrint('PROPERTY INSERT RESULT: $insertedProperty');

      debugPrint('REGISTRATION STEP 3: Property created');

      // ----------------------------------------------------------
      // 4. Create the requested units in Supabase.
      // ----------------------------------------------------------
      final numberOfUnits = int.tryParse(_unitsController.text.trim()) ?? 0;

      final propertyId = insertedProperty['id']?.toString() ?? '';

      if (propertyId.isNotEmpty && numberOfUnits > 0) {
        final unitRows = List.generate(
          numberOfUnits,
          (index) => {
            'property_id': propertyId,
            'unit_number': '${index + 1}',
            'unit_type': 'Apartment',
            'description': '',
            'monthly_rent': 0,
            'status': 'vacant',
          },
        );

        await OpenNestStore.supabase.from('units').insert(unitRows);
      }

      // ----------------------------------------------------------
      // 5. Keep the existing local owner system working.
      // ----------------------------------------------------------
      final owner = Owner(
        id: user.id,
        fullName: ownerName,
        email: email,
        phone: phone,
        password: password,
        propertyName: propertyName,
        location: location,
        units: _unitsController.text.trim(),
        address: address,
      );

      OpenNestStore.owners.add(owner);
      await OpenNestStore.saveOwners();

      // ----------------------------------------------------------
      // 6. Reload properties and units from Supabase.
      // ----------------------------------------------------------
      await OpenNestStore.loadPropertiesFromSupabase();
      await OpenNestStore.loadUnitsFromSupabase();

      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account and property created successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      debugPrint('REGISTRATION STEP 4: Units created');
      debugPrint('REGISTRATION STEP 5: Opening Dashboard');

      // Open the existing Owner/Admin Dashboard.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
            onDarkModeChanged: (enabled) {
              final state = context
                  .findAncestorStateOfType<_ApartmentAppState>();
              state?._setDarkMode(enabled);
            },
          ),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account creation failed: ${e.message}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('REGISTRATION ERROR TYPE: ${e.runtimeType}');
      debugPrint('REGISTRATION ERROR: $e');
      debugPrint('REGISTRATION STACK TRACE: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0B3D2E),
        title: const Text(
          'Register Apartment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B3D2E), Color(0xFF126B4F)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.apartment_rounded, color: Colors.white, size: 34),
                  SizedBox(height: 16),
                  Text(
                    'Create your JUMAA property',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Register your property and create your Owner account.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            const Text(
              'Owner Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3D2E),
              ),
            ),

            const SizedBox(height: 12),

            _field(
              controller: _ownerNameController,
              label: 'Full Name',
              hint: 'e.g. John Kamau',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your full name';
                }
                return null;
              },
            ),

            _field(
              controller: _phoneController,
              label: 'Phone Number',
              hint: 'e.g. 0712345678',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your phone number';
                }
                return null;
              },
            ),

            _field(
              controller: _emailController,
              label: 'Email Address',
              hint: 'you@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your email';
                }

                if (!value.contains('@')) {
                  return 'Enter a valid email';
                }

                return null;
              },
            ),

            _field(
              controller: _passwordController,
              label: 'Password',
              hint: 'Create a secure password',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) {
                if (value == null || value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),

            _field(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              icon: Icons.lock_reset_outlined,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }

                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }

                return null;
              },
            ),

            const SizedBox(height: 5),

            StatefulBuilder(
              builder: (context, setLocalState) {
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _acceptedTerms,
                  onChanged: (value) {
                    setState(() {
                      _acceptedTerms = value ?? false;
                    });
                  },
                  title: Wrap(
                    children: [
                      const Text(
                        'I agree to the ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF263238),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text(
                                  'Terms & Conditions',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0B3D2E),
                                  ),
                                ),
                                content: const SingleChildScrollView(
                                  child: Text(
                                    'By creating an JUMAA account, you agree to use the platform responsibly and provide accurate information. '
                                    'You are responsible for keeping your account credentials secure. '
                                    'Property information submitted to JUMAA should be accurate and up to date. '
                                    'JUMAA reserves the right to review or remove information that violates the platform rules.',
                                    style: TextStyle(fontSize: 14, height: 1.5),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Close'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: const Text(
                          'Terms & Conditions',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0B3D2E),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            const Text(
              'Property Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3D2E),
              ),
            ),

            const SizedBox(height: 12),

            _field(
              controller: _propertyNameController,
              label: 'Property / Apartment Name',
              hint: 'e.g. Green Valley Apartments',
              icon: Icons.home_work_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the property name';
                }
                return null;
              },
            ),

            DropdownButtonFormField<String>(
              initialValue: _selectedCounty,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                labelText: 'County',
                prefixIcon: Icon(Icons.location_city_outlined),
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select county'),
              items: _counties.map((county) {
                return DropdownMenuItem<String>(
                  value: county,
                  child: Text(county),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCounty = value;
                  _selectedSubcounty = null;
                  _selectedArea = null;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Select a county';
                }
                return null;
              },
            ),

            const SizedBox(height: 9),

            DropdownButtonFormField<String>(
              initialValue: _selectedSubcounty,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                labelText: 'Subcounty',
                prefixIcon: Icon(Icons.map_outlined),
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select subcounty'),
              items: _subcounties.map((subcounty) {
                return DropdownMenuItem<String>(
                  value: subcounty,
                  child: Text(subcounty),
                );
              }).toList(),
              onChanged: _selectedCounty == null
                  ? null
                  : (value) {
                      setState(() {
                        _selectedSubcounty = value;
                        _selectedArea = null;
                      });
                    },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Select a subcounty';
                }
                return null;
              },
            ),

            const SizedBox(height: 9),

            DropdownButtonFormField<String>(
              initialValue: _selectedArea,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                labelText: 'Area',
                prefixIcon: Icon(Icons.place_outlined),
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select area'),
              items: _areas.map((area) {
                return DropdownMenuItem<String>(value: area, child: Text(area));
              }).toList(),
              onChanged: _selectedSubcounty == null
                  ? null
                  : (value) {
                      setState(() {
                        _selectedArea = value;
                      });
                    },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Select an area';
                }
                return null;
              },
            ),

            _field(
              controller: _unitsController,
              label: 'Number of Units',
              hint: 'e.g. 24',
              icon: Icons.grid_view_outlined,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter number of units';
                }

                if (int.tryParse(value) == null) {
                  return 'Enter a valid number';
                }

                return null;
              },
            ),

            _field(
              controller: _addressController,
              label: 'Property Address',
              hint: 'Enter the full address',
              icon: Icons.map_outlined,
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the property address';
                }
                return null;
              },
            ),

            const SizedBox(height: 18),

            // Information card
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F3EF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF0B3D2E)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your Owner account will give you access to the JUMAA property management dashboard.',
                      style: TextStyle(
                        color: Color(0xFF285548),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createOwnerAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B3D2E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'CREATE OWNER ACCOUNT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: .4,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'By continuing, you agree to use JUMAA responsibly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLines: obscureText ? 1 : maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: const Color(0xFF39B982),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white70),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFF39B982),
            fontWeight: FontWeight.w600,
          ),
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.white70),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: const Color(0xFF171717),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF39B982), width: 1.5),
          ),
        ),
      ),
    );
  }
}
// ============================================================
// JUMAA - PUBLIC USER / APARTMENT SEARCH
// ============================================================

class PublicUserPage extends StatefulWidget {
  const PublicUserPage({super.key});

  @override
  State<PublicUserPage> createState() => _PublicUserPageState();
}

class _PublicUserPageState extends State<PublicUserPage> {
  final TextEditingController _searchController = TextEditingController();

  String _search = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Apartment> get _apartments {
    final results = OpenNestStore.apartments.where((apartment) {
      if (_search.isEmpty) return true;

      return apartment.number.toLowerCase().contains(_search) ||
          apartment.type.toLowerCase().contains(_search) ||
          apartment.rent.toLowerCase().contains(_search) ||
          apartment.tenant.toLowerCase().contains(_search);
    }).toList();

    // Boosted listings first.
    results.sort((a, b) {
      if (a.isBoosted && !b.isBoosted) return -1;
      if (!a.isBoosted && b.isBoosted) return 1;
      return 0;
    });

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final apartments = _apartments;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Find an Apartment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Find your next home',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B3D2E),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Search apartments and connect with landlords.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by apartment, type or rent...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              '${apartments.length} apartment${apartments.length == 1 ? '' : 's'} found',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: apartments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.home_work_outlined,
                            size: 70,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'No apartments found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try another search.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: apartments.length,
                      itemBuilder: (context, index) {
                        return _apartmentCard(apartments[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _apartmentCard(Apartment apartment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F3EE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.apartment,
                    color: Color(0xFF0B3D2E),
                    size: 30,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              apartment.number,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          if (apartment.isBoosted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'BOOSTED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(apartment.type),

                      const SizedBox(height: 4),

                      Text(
                        apartment.rent,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B3D2E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 19,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    apartment.location.isEmpty
                        ? 'Location not provided'
                        : apartment.location,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: apartment.status == 'Vacant'
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                apartment.status,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: apartment.status == 'Vacant'
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        apartment.location.isEmpty
                            ? 'No location has been added yet.'
                            : 'Location: ${apartment.location}',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('View Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// JUMAA - LOGIN
// ============================================================

class JUMAALoginPage extends StatefulWidget {
  const JUMAALoginPage({super.key});

  @override
  State<JUMAALoginPage> createState() => _JUMAALoginPageState();
}

class _JUMAALoginPageState extends State<JUMAALoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and password.')),
      );
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    await OpenNestStore.loadOwners();

    final owner = OpenNestStore.findOwnerByEmail(email);

    if (!mounted) return;

    if (owner != null && owner.password.trim() == password) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('jumaa_logged_in', true);
      await prefs.setString('jumaa_logged_in_email', owner.email);

      if (!mounted) return;

      setState(() {
        _isLoggingIn = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
            onDarkModeChanged: (enabled) {
              final state = context
                  .findAncestorStateOfType<_ApartmentAppState>();
              state?._setDarkMode(enabled);
            },
          ),
        ),
      );

      return;
    }

    setState(() {
      _isLoggingIn = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Invalid email or password. Check your details and try again.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _forgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JUMAAForgotPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 25),

          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: const Color(0xFF0B3D2E),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.home_work_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B3D2E),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Login to your JUMAA account.',
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),

          const SizedBox(height: 35),

          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              child: const Text('Forgot password?'),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoggingIn ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B3D2E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: _isLoggingIn
                  ? const SizedBox(
                      width: 23,
                      height: 23,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'LOGIN',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),

          const SizedBox(height: 22),

          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Create an account'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// JUMAA - FORGOT PASSWORD
// ============================================================

class JUMAAForgotPasswordPage extends StatefulWidget {
  const JUMAAForgotPasswordPage({super.key});

  @override
  State<JUMAAForgotPasswordPage> createState() =>
      _JUMAAForgotPasswordPageState();
}

class _JUMAAForgotPasswordPageState extends State<JUMAAForgotPasswordPage> {
  final _emailController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    await OpenNestStore.loadLandlords();

    if (!mounted) return;

    final landlord = OpenNestStore.findLandlordByEmail(email);

    if (landlord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No JUMAA account was found with this email.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    final code = (10000 + DateTime.now().millisecondsSinceEpoch % 90000)
        .toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JUMAAVerifyCodePage(landlord: landlord, code: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 30),

          const Icon(
            Icons.lock_reset_rounded,
            size: 70,
            color: Color(0xFF0B3D2E),
          ),

          const SizedBox(height: 25),

          const Text(
            'Forgot your password?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B3D2E),
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Enter your JUMAA email address and we will send a verification code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),

          const SizedBox(height: 30),

          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email address',
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 22),

          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B3D2E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'SEND VERIFICATION CODE',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'Prototype mode: the verification code will be displayed in the next screen. We will connect this to real email delivery next.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// JUMAA - VERIFY RESET CODE
// ============================================================

class JUMAAVerifyCodePage extends StatefulWidget {
  const JUMAAVerifyCodePage({
    super.key,
    required this.landlord,
    required this.code,
  });

  final Landlord landlord;
  final String code;

  @override
  State<JUMAAVerifyCodePage> createState() => _JUMAAVerifyCodePageState();
}

class _JUMAAVerifyCodePageState extends State<JUMAAVerifyCodePage> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _verify() {
    if (_codeController.text.trim() != widget.code) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect verification code.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => JUMAACreateNewPasswordPage(landlord: widget.landlord),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 25),

          const Icon(
            Icons.mark_email_read_outlined,
            size: 70,
            color: Color(0xFF0B3D2E),
          ),

          const SizedBox(height: 22),

          const Text(
            'Check your email',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B3D2E),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'A verification code was sent to ${widget.landlord.email}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),

          const SizedBox(height: 25),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3EF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Text(
                  'Your JUMAA verification code is',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF285548)),
                ),

                const SizedBox(height: 10),

                Text(
                  widget.code,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    color: Color(0xFF0B3D2E),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Don't share this code with anyone.",
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 5,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'Enter verification code',
              prefixIcon: const Icon(Icons.pin_outlined),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 15),

          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B3D2E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: const Text(
                'VERIFY CODE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// JUMAA - CREATE NEW PASSWORD
// ============================================================

class JUMAACreateNewPasswordPage extends StatefulWidget {
  const JUMAACreateNewPasswordPage({super.key, required this.landlord});

  final Landlord landlord;

  @override
  State<JUMAACreateNewPasswordPage> createState() =>
      _JUMAACreateNewPasswordPageState();
}

class _JUMAACreateNewPasswordPageState
    extends State<JUMAACreateNewPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    setState(() {
      _saving = true;
    });

    widget.landlord.temporaryPassword = password;
    widget.landlord.mustResetPassword = false;

    await OpenNestStore.saveLandlords();

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const JUMAALoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        title: const Text('Create New Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 30),

          const Icon(
            Icons.password_rounded,
            size: 70,
            color: Color(0xFF0B3D2E),
          ),

          const SizedBox(height: 22),

          const Text(
            'Create a new password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B3D2E),
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Choose a strong password for your JUMAA account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),

          const SizedBox(height: 30),

          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureConfirm = !_obscureConfirm;
                  });
                },
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 25),

          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _saving ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B3D2E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'RESET PASSWORD',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages.add({'text': text, 'isMe': true, 'time': DateTime.now()});
    });

    _messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),

        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF1976D2),
              child: Icon(Icons.support_agent, color: Colors.white, size: 20),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Support',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];

                        return _buildMessage(
                          message['text'] as String,
                          message['isMe'] as bool,
                          message['time'] as DateTime,
                        );
                      },
                    ),
            ),

            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: Color(0xFF1976D2),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Start a conversation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 8),

            const Text(
              'Send a message to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(String text, bool isMe, DateTime time) {
    final timeString =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1976D2) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),

            const SizedBox(height: 4),

            Text(
              timeString,
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: const Color(0xFFF2F3F5),

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF1976D2)),
                ),
              ),

              onSubmitted: (_) => _sendMessage(),
            ),
          ),

          const SizedBox(width: 8),

          Material(
            color: const Color(0xFF1976D2),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _sendMessage,
              child: const Padding(
                padding: EdgeInsets.all(13),
                child: Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
