import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pdezijwjfqyulkkuhoun.supabase.co',
    publishableKey: 'sb_publishable_wFuJsdho3es8WrD4vkqC_A_8MLx_0ft',
  );

  await OpenNestStore.loadLandlords();

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

  void _setDarkMode(bool enabled) {
    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OpenNest',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: const Color(0xFFF8F7FC),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: const OpenNestWelcomePage(),
    );
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

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardHome(),
      const ManageApartmentsPage(),
      const TenantsPage(),
      SettingsPage(
        isDarkMode: widget.isDarkMode,
        onDarkModeChanged: widget.onDarkModeChanged,
      ),
    ];

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment),
            label: 'Apartments',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Tenants',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            const Text(
              'Apartment App',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 18),

            const Text(
              'Welcome back 👋',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              'Manage your apartment easily.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.apartment,
                    value: totalApartments.toString(),
                    title: 'Apartments',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    icon: Icons.people,
                    value: occupied.toString(),
                    title: 'Occupied',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

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

            const SizedBox(height: 24),

            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 25),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
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
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 20),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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
        appBar: AppBar(title: const Text('Apartment Management')),
        body: const Center(
          child: Text('No apartment has been registered yet.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Apartment Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B3D2E), Color(0xFF126B4F)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.apartment_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    currentProperty.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          currentProperty.location.isEmpty
                              ? 'Location not provided'
                              : currentProperty.location,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _managementStat(
                    'Total Units',
                    units.length.toString(),
                    Icons.home_work_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _managementStat(
                    'Occupied',
                    occupied.toString(),
                    Icons.people_outline,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _managementStat(
                    'Vacant',
                    vacant.toString(),
                    Icons.home_outlined,
                  ),
                ),
                const SizedBox(width: 10),
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
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 9),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
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

  void saveProperty() {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apartment name is required.')),
      );
      return;
    }

    widget.property.name = name;
    widget.property.location = locationController.text.trim();
    widget.property.address = addressController.text.trim();
    widget.property.phone = phoneController.text.trim();
    widget.property.email = emailController.text.trim();
    widget.property.description = descriptionController.text.trim();

    // Keep the existing unit records synchronized with the
    // property information.
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
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
                  '${unit.type} • ${unit.rent}\n${unit.tenant.isEmpty ? 'No tenant' : unit.tenant}',
                ),
                isThreeLine: true,
                trailing: _statusBadge(unit.status),
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
            const Padding(
              padding: EdgeInsets.all(35),
              child: Column(
                children: [
                  Icon(Icons.home_work_outlined, size: 55),
                  SizedBox(height: 12),
                  Text(
                    'No units are connected to this property yet.',
                    textAlign: TextAlign.center,
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
              DropdownMenuItem(value: 'Occupied', child: Text('Occupied')),
              DropdownMenuItem(value: 'Vacant', child: Text('Vacant')),
              DropdownMenuItem(
                value: 'Maintenance',
                child: Text('Maintenance'),
              ),
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
  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final units = OpenNestStore.apartments
        .where((u) => u.propertyId == property.id)
        .toList();
    final images = property.imagePaths;

    final availableUnits = units
        .where((unit) => unit.status == 'Vacant')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Apartment Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: 270,
              child: PageView.builder(
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Image.file(
                    File(images[index]),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return _placeholder();
                    },
                  );
                },
              ),
            )
          else
            SizedBox(height: 270, child: _placeholder()),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.name,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        property.location,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  'About this apartment',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 9),

                Text(
                  property.description,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 26),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Available Units',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${availableUnits.length} available',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (availableUnits.isEmpty)
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey.shade600),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('There are currently no vacant units.'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...availableUnits.map((unit) => _publicUnitCard(unit)),

                const SizedBox(height: 28),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _startChat,
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('CHAT'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: availableUnits.isEmpty
                            ? null
                            : _openBookingForm,
                        icon: const Icon(Icons.event_available),
                        label: const Text('BOOK NOW'),
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
        ],
      ),
    );
  }

  Widget _publicUnitCard(Apartment unit) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.home_outlined),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room ${unit.number}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unit.type,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unit.rent,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Widget _placeholder() {
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
      child: Center(
        child: Icon(
          Icons.apartment,
          size: 75,
          color: Theme.of(context).colorScheme.primary,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking form is being prepared.')),
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
                        builder: (_) => const RegisterApartmentPage(),
                      ),
                    ).then((_) => _refresh());
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

  void _refresh() {
    setState(() {});
  }

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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unit management can be connected to the existing unit form.',
                      ),
                    ),
                  );
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
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            available ? Icons.check_circle_outline : Icons.person_outline,
          ),
        ),
        title: Text(
          unit.number,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${unit.type} • ${unit.rent}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          unit.status,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: available ? Colors.green.shade700 : Colors.orange.shade700,
          ),
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

  List<Apartment> get apartments => OpenNestStore.apartments;

  List<Property> get properties => OpenNestStore.properties;

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

  String propertyLocation(String propertyId) {
    final property = propertyById(propertyId);

    if (property == null || property.location.trim().isEmpty) {
      return 'Location not provided';
    }

    return property.location;
  }

  String propertyDescription(String propertyId) {
    final property = propertyById(propertyId);

    if (property == null || property.description.trim().isEmpty) {
      return 'Beautiful apartments with comfortable living spaces and convenient amenities.';
    }

    return property.description;
  }

  @override
  Widget build(BuildContext context) {
    final filteredProperties = properties.where((property) {
      if (searchQuery.trim().isEmpty) {
        return true;
      }

      final query = searchQuery.toLowerCase();

      return property.name.toLowerCase().contains(query) ||
          propertyLocation(property.id).toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Find an Apartment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search properties...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            searchQuery = '';
                          });
                        },
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${filteredProperties.length} properties',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.sort, size: 19),
                const SizedBox(width: 4),
                const Text('Latest', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: filteredProperties.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: filteredProperties.length,
                    itemBuilder: (context, index) {
                      final property = filteredProperties[index];

                      return _propertyCard(property);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _propertyCard(Property property) {
    final units = unitsForProperty(property.id);
    final available = units.where((u) => u.status == 'Vacant').length;
    final images = propertyImages(property.id);
    final location = propertyLocation(property.id);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _showPropertyDetails(property);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 190,
              width: double.infinity,
              child: images.isNotEmpty
                  ? Image.file(
                      File(images.first),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return _propertyPlaceholder();
                      },
                    )
                  : _propertyPlaceholder(),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    propertyDescription(property.id),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, height: 1.4),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      _infoPill(
                        Icons.apartment_outlined,
                        '${units.length} units',
                      ),
                      const SizedBox(width: 8),
                      _infoPill(
                        Icons.check_circle_outline,
                        '$available available',
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        _showPropertyDetails(property);
                      },
                      child: const Text('VIEW APARTMENT'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _propertyPlaceholder() {
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
      child: Center(
        child: Icon(
          Icons.apartment,
          size: 70,
          color: Theme.of(context).colorScheme.primary,
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
              Icons.apartment_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 15),
            const Text(
              'No apartments found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try another search.',
              style: TextStyle(color: Colors.black54),
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

  Widget _unitCard(BuildContext sheetContext, Apartment apartment) {
    final available = apartment.status == 'Vacant';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.home_outlined),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room ${apartment.number}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    apartment.type,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    apartment.rent,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: available ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                available ? 'Available' : apartment.status,
                style: TextStyle(
                  color: available
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatMessage(BuildContext context) {
    // First, determine who the landlord is for this property
    // For now, use a dialog to start a new conversation
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Chat'),
        content: const Text(
          'This will open a chat with the property landlord. '
          'You\'ll be able to ask questions and confirm availability.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // TODO: Replace with actual landlord ID once auth is hooked up
              // For now we navigate to the chat list
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatListScreen()),
              );
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  void _showBookingForm(Property property) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final idController = TextEditingController();
    final messageController = TextEditingController();

    String? selectedUnit;

    final availableUnits = unitsForProperty(property.id)
        .where((unit) => unit.status == 'Vacant')
        .toList();

    if (availableUnits.isNotEmpty) {
      selectedUnit = availableUnits.first.number;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (formContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 760),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book ${property.name}',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 7),

                      const Text(
                        'Submit your details and the landlord will review your booking request.',
                        style: TextStyle(color: Colors.black54, height: 1.4),
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

                      TextField(
                        controller: idController,
                        decoration: const InputDecoration(
                          labelText: 'ID / Passport Number',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),

                      const SizedBox(height: 14),

                      if (availableUnits.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Preferred Unit',
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                          items: availableUnits
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit.number,
                                  child: Text(
                                    '${unit.number} • ${unit.type} • ${unit.rent}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setModalState(() {
                              selectedUnit = value;
                            });
                          },
                        )
                      else
                        const Text(
                          'There are currently no vacant units.',
                          style: TextStyle(color: Colors.red),
                        ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: messageController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Additional Message',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.message_outlined),
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: availableUnits.isEmpty
                              ? null
                              : () {
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

                                  Navigator.pop(formContext);

                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Booking submitted successfully. An email will be sent to you shortly with an update on your booking.',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          duration: Duration(seconds: 5),
                                        ),
                                      );
                                },
                          child: const Text('SUBMIT BOOKING'),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Center(
                        child: Text(
                          'Your booking details will be reviewed by the landlord.',
                          style: TextStyle(fontSize: 12, color: Colors.black45),
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

// ============================================================
// PAYMENTS PAGE
// ============================================================

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const Center(
        child: Text(
          'Payments',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
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

// ============================================================
// OWNER / ADMIN MODEL
// ============================================================

class Owner {
  String id;
  String fullName;
  String email;
  String phone;
  String password;
  String propertyName;
  String location;
  String units;
  String address;

  Owner({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.propertyName,
    required this.location,
    required this.units,
    required this.address,
  });
}

// ============================================================
// PROPERTY MODEL
// ============================================================

class Property {
  String id;
  String name;
  String location;
  String address;
  String description;
  String email;
  String phone;
  List<String> imagePaths;
  List<String> videoPaths;

  Property({
    required this.id,
    required this.name,
    this.location = '',
    this.address = '',
    this.description = '',
    this.email = '',
    this.phone = '',
    this.imagePaths = const [],
    this.videoPaths = const [],
  });
}

// ============================================================
// OPENNEST SHARED DATA STORE
// ============================================================

class OpenNestStore {
  // ============================================================
  // PROPERTIES
  // ============================================================

  static final List<Property> properties = [
    Property(
      id: 'property_001',
      name: 'Greenview Apartments',
      location: 'Nairobi, Kenya',
      address: 'Nairobi, Kenya',
      description: 'A comfortable modern apartment with secure parking, reliable water and convenient access to nearby services.',
      email: '',
      phone: '',
    ),
  ];

  static final List<Apartment> apartments = [
    Apartment(
      number: 'A101',
      propertyId: 'property_001',
      type: '2 Bedroom',
      rent: 'KSh 25000',
      tenant: 'John Kamau',
      status: 'Occupied',
      propertyName: 'Greenview Apartments',
      location: 'Nairobi, Kenya',
      description: 'A comfortable modern apartment with secure parking, reliable water and convenient access to nearby services.',
    ),
    Apartment(
      number: 'A102',
      propertyId: 'property_001',
      type: '1 Bedroom',
      rent: 'KSh 18000',
      tenant: '',
      status: 'Vacant',
      propertyName: 'Greenview Apartments',
      location: 'Nairobi, Kenya',
      description: 'A comfortable modern apartment with secure parking, reliable water and convenient access to nearby services.',
    ),
    Apartment(
      number: 'A103',
      propertyId: 'property_001',
      type: 'Bedsitter',
      rent: 'KSh 10000',
      tenant: '',
      status: 'Vacant',
      propertyName: 'Greenview Apartments',
      location: 'Nairobi, Kenya',
      description: 'A comfortable modern apartment with secure parking, reliable water and convenient access to nearby services.',
    ),
  ];

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
}

// ============================================================
// APARTMENT MODEL
// ===========================================================

class Apartment {
  String number;
  String type;
  String rent;
  String tenant;
  String status;

  // Property this unit belongs to
  String propertyId;
  String propertyName;

  // Marketplace information
  String location;
  String description;
  List<String> imagePaths;
  List<String> videoPaths;

  // Boost information
  bool isBoosted;
  DateTime? boostExpiresAt;

  Apartment({
    required this.number,
    required this.type,
    required this.rent,
    required this.tenant,
    required this.status,
    this.propertyId = 'property_001',
    this.propertyName = 'Greenview Apartments',
    this.location = '',
    this.description = '',
    this.imagePaths = const [],
    this.videoPaths = const [],
    this.isBoosted = false,
    this.boostExpiresAt,
  });

  bool get boostIsActive {
    if (!isBoosted || boostExpiresAt == null) {
      return false;
    }

    return DateTime.now().isBefore(boostExpiresAt!);
  }
}

// ============================================================
// TENANTS PLACEHOLDER
// ============================================================

class TenantsPage extends StatefulWidget {
  const TenantsPage({super.key});

  @override
  State<TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends State<TenantsPage> {
  String searchQuery = '';

  final List<Tenant> tenants = [
    Tenant(
      name: 'John Kamau',
      phone: '0712 345 678',
      apartment: 'A101',
      rent: 'KSh 18,000',
      paymentStatus: 'Paid',
    ),
    Tenant(
      name: 'Mary Wanjiku',
      phone: '0722 456 789',
      apartment: 'A102',
      rent: 'KSh 25,000',
      paymentStatus: 'Pending',
    ),
    Tenant(
      name: 'Brian Otieno',
      phone: '0733 567 890',
      apartment: 'A104',
      rent: 'KSh 35,000',
      paymentStatus: 'Paid',
    ),
    Tenant(
      name: 'Jane Njeri',
      phone: '0744 678 901',
      apartment: 'B202',
      rent: 'KSh 18,000',
      paymentStatus: 'Overdue',
    ),
    Tenant(
      name: 'David Mwangi',
      phone: '0755 789 012',
      apartment: 'B204',
      rent: 'KSh 35,000',
      paymentStatus: 'Paid',
    ),
  ];

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
            child: filteredTenants.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filteredTenants.length,
                    itemBuilder: (context, index) {
                      return _tenantCard(filteredTenants[index]);
                    },
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
              CircleAvatar(
                radius: 25,
                child: Text(
                  tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
    final phoneController = TextEditingController();
    final apartmentController = TextEditingController();
    final rentController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
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
                    labelText: 'Apartment',
                    hintText: 'e.g. A105',
                    prefixIcon: Icon(Icons.apartment),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monthly rent',
                    prefixIcon: Icon(Icons.payments),
                    prefixText: 'KSh ',
                  ),
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
                if (nameController.text.trim().isEmpty ||
                    phoneController.text.trim().isEmpty ||
                    apartmentController.text.trim().isEmpty ||
                    rentController.text.trim().isEmpty) {
                  return;
                }

                setState(() {
                  tenants.add(
                    Tenant(
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      apartment: apartmentController.text.trim().toUpperCase(),
                      rent: 'KSh ${rentController.text.trim()}',
                      paymentStatus: 'Pending',
                    ),
                  );
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
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
                      value: status,
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
// ============================================================

class Landlord {
  String id;
  String fullName;
  String email;
  String phone;
  String temporaryPassword;
  bool mustResetPassword;
  String apartmentName;

  Landlord({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.temporaryPassword,
    required this.mustResetPassword,
    required this.apartmentName,
  });
}

// ============================================================
// LANDLORD LOGIN
// ============================================================

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

  void _login() {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and password.')),
      );
      return;
    }

    final landlord = OpenNestStore.landlords.cast<Landlord?>().firstWhere(
      (l) =>
          l != null &&
          l.email.trim().toLowerCase() == email &&
          l.temporaryPassword == password,
      orElse: () => null,
    );

    if (landlord != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LandlordDashboardPage(landlord: landlord),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invalid email or password.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

class LandlordDashboardPage extends StatelessWidget {
  final Landlord landlord;

  const LandlordDashboardPage({super.key, required this.landlord});

  @override
  Widget build(BuildContext context) {
    final assignedApartments = OpenNestStore.apartments
        .where((apartment) => apartment.number == landlord.apartmentName)
        .toList();

    final occupied = assignedApartments
        .where((apartment) => apartment.status == 'Occupied')
        .length;

    final vacant = assignedApartments
        .where((apartment) => apartment.status == 'Vacant')
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Landlord Dashboard')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${landlord.fullName} 👋',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Landlord ID: ${landlord.id}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.apartment)),
                  title: const Text(
                    'Assigned Apartment',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(landlord.apartmentName),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _landlordStat(
                      context,
                      Icons.apartment,
                      assignedApartments.length.toString(),
                      'Units',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _landlordStat(
                      context,
                      Icons.people_outline,
                      occupied.toString(),
                      'Occupied',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _landlordStat(
                      context,
                      Icons.home_outlined,
                      vacant.toString(),
                      'Vacant',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _landlordAction(
                context,
                Icons.apartment,
                'View My Apartments',
                () {},
              ),
              _landlordAction(
                context,
                Icons.calendar_month_outlined,
                'Booking Requests',
                () {},
              ),
              _landlordAction(
                context,
                Icons.chat_bubble_outline,
                'Messages',
                () {},
              ),
              _landlordAction(
                context,
                Icons.build_outlined,
                'Maintenance Requests',
                () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _landlordStat(
    BuildContext context,
    IconData icon,
    String value,
    String title,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _landlordAction(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
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
                  'Welcome to OpenNest! 🏠',
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
// ============================================================

class Tenant {
  String name;
  String phone;
  String apartment;
  String rent;
  String paymentStatus;

  Tenant({
    required this.name,
    required this.phone,
    required this.apartment,
    required this.rent,
    required this.paymentStatus,
  });
}

// ============================================================
// SETTINGS
// ============================================================

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
                  subtitle: const Text('Get help using Apartment App'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showHelpAndSupport,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: const Text('Apartment App v1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showAbout,
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),
          Center(
            child: Text(
              'Apartment App',
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
              RadioListTile<String>(
                value: 'English',
                groupValue: tempLanguage,
                title: const Text('English'),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => tempLanguage = value);
                  }
                },
              ),
              RadioListTile<String>(
                value: 'Swahili',
                groupValue: tempLanguage,
                title: const Text('Kiswahili'),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => tempLanguage = value);
                  }
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
                  value: tempType,
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
    int tempDueDay = rentDueDay;
    bool tempReminders = paymentReminders;
    bool tempAutoOverdue = autoMarkOverdue;

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
                  value: tempDueDay,
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
                const SizedBox(height: 8),
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  rentDueDay = tempDueDay;
                  paymentReminders = tempReminders;
                  autoMarkOverdue = tempAutoOverdue;
                });
                Navigator.pop(dialogContext);
                _showMessage('Payment settings saved.');
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
      applicationName: 'Apartment App',
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
// OPENNEST WELCOME / ENTRY SCREEN
// ============================================================

class OpenNestWelcomePage extends StatelessWidget {
  const OpenNestWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B3D2E), Color(0xFF126B4F), Color(0xFF1B8A67)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(),

                // Logo
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.home_work_rounded,
                    color: Colors.white,
                    size: 46,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'OpenNest',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Find a place to call home.\nManage a place you call yours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 48),

                // Register Apartment
                _entryButton(
                  context,
                  icon: Icons.apartment_rounded,
                  title: 'Register an Apartment',
                  subtitle: 'Create your Owner account',
                  filled: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterApartmentPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                // Find Apartment
                _entryButton(
                  context,
                  icon: Icons.search_rounded,
                  title: 'Find an Apartment',
                  subtitle: 'Discover your next home',
                  filled: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ApartmentsPage()),
                    );
                  },
                ),

                const SizedBox(height: 28),

                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'Already have an account?',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OpenNestLoginPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'LOGIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                const Spacer(),

                const Text(
                  'OPENNEST • FIND • RENT • MANAGE',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: filled ? Colors.white : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: filled
                        ? const Color(0xFF0B3D2E)
                        : Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: Colors.white, size: 25),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: filled
                              ? const Color(0xFF0B3D2E)
                              : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: filled ? Colors.black54 : Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: filled ? const Color(0xFF0B3D2E) : Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// ============================================================
// OPENNEST - REGISTER APARTMENT / OWNER ACCOUNT
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
  final _locationController = TextEditingController();
  final _unitsController = TextEditingController();
  final _addressController = TextEditingController();

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
    _locationController.dispose();
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

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    final existing = OpenNestStore.findOwnerByEmail(email);

    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'An owner account with this email already exists. Please log in.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    final owner = Owner(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: _ownerNameController.text.trim(),
      email: email,
      phone: _phoneController.text.trim(),
      password: password,
      propertyName: _propertyNameController.text.trim(),
      location: _locationController.text.trim(),
      units: _unitsController.text.trim(),
      address: _addressController.text.trim(),
    );

    OpenNestStore.owners.add(owner);

    await OpenNestStore.saveOwners();

    if (!mounted) return;

    setState(() {
      _isCreating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account created successfully. You can now log in.'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OpenNestLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
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
                    'Create your OpenNest property',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
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
                fontSize: 18,
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

            const SizedBox(height: 8),

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
                                    'By creating an OpenNest account, you agree to use the platform responsibly and provide accurate information. '
                                    'You are responsible for keeping your account credentials secure. '
                                    'Property information submitted to OpenNest should be accurate and up to date. '
                                    'OpenNest reserves the right to review or remove information that violates the platform rules.',
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
                fontSize: 18,
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

            _field(
              controller: _locationController,
              label: 'Location',
              hint: 'e.g. Bomet',
              icon: Icons.location_on_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the property location';
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
                      'Your Owner account will give you access to the OpenNest property management dashboard.',
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
              'By continuing, you agree to use OpenNest responsibly.',
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
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: .06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF0B3D2E), width: 1.5),
          ),
        ),
      ),
    );
  }
}
// ============================================================
// OPENNEST - PUBLIC USER / APARTMENT SEARCH
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
// OPENNEST - LOGIN
// ============================================================

class OpenNestLoginPage extends StatefulWidget {
  const OpenNestLoginPage({super.key});

  @override
  State<OpenNestLoginPage> createState() => _OpenNestLoginPageState();
}

class _OpenNestLoginPageState extends State<OpenNestLoginPage> {
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
      MaterialPageRoute(builder: (_) => const OpenNestForgotPasswordPage()),
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
            'Login to your OpenNest account.',
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
// OPENNEST - FORGOT PASSWORD
// ============================================================

class OpenNestForgotPasswordPage extends StatefulWidget {
  const OpenNestForgotPasswordPage({super.key});

  @override
  State<OpenNestForgotPasswordPage> createState() =>
      _OpenNestForgotPasswordPageState();
}

class _OpenNestForgotPasswordPageState
    extends State<OpenNestForgotPasswordPage> {
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

    final landlord = OpenNestStore.findLandlordByEmail(email);

    if (landlord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No OpenNest account was found with this email.'),
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
        builder: (_) => OpenNestVerifyCodePage(landlord: landlord, code: code),
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
            'Enter your OpenNest email address and we will send a verification code.',
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
// OPENNEST - VERIFY RESET CODE
// ============================================================

class OpenNestVerifyCodePage extends StatefulWidget {
  const OpenNestVerifyCodePage({
    super.key,
    required this.landlord,
    required this.code,
  });

  final Landlord landlord;
  final String code;

  @override
  State<OpenNestVerifyCodePage> createState() => _OpenNestVerifyCodePageState();
}

class _OpenNestVerifyCodePageState extends State<OpenNestVerifyCodePage> {
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
        builder: (_) =>
            OpenNestCreateNewPasswordPage(landlord: widget.landlord),
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
                  'Your OpenNest verification code is',
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
// OPENNEST - CREATE NEW PASSWORD
// ============================================================

class OpenNestCreateNewPasswordPage extends StatefulWidget {
  const OpenNestCreateNewPasswordPage({super.key, required this.landlord});

  final Landlord landlord;

  @override
  State<OpenNestCreateNewPasswordPage> createState() =>
      _OpenNestCreateNewPasswordPageState();
}

class _OpenNestCreateNewPasswordPageState
    extends State<OpenNestCreateNewPasswordPage> {
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
      MaterialPageRoute(builder: (_) => const OpenNestLoginPage()),
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
            'Choose a strong password for your OpenNest account.',
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
                color: Colors.blue.withOpacity(0.10),
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
              color: Colors.black.withOpacity(0.04),
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
            color: Colors.black.withOpacity(0.08),
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
