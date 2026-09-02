import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import 'models/owner.dart';
import 'models/property.dart';
import 'models/apartment.dart';
import 'models/landlord.dart';
import 'models/tenant.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/landlord/landlord_dashboard.dart';
import 'screens/jumaa_owner/jumaa_owner_dashboard.dart';
import 'services/booking_service.dart';

// ============================================================
// JUMAA EMAIL SERVICE
// ============================================================

class JumaaEmailService {
  static const String _functionUrl =
      'https://pdezijwjfqyulkkuhoun.supabase.co/functions/v1/send-email';

  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String html,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'to': to.trim(), 'subject': subject, 'html': html}),
      );

      debugPrint(
        'JUMAA EMAIL: status=${response.statusCode} body=${response.body}',
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('JUMAA EMAIL ERROR: $e');
      return false;
    }
  }

  static Future<bool> sendLandlordInvitation({
    required String name,
    required String email,
    required String landlordId,
    required String phone,
    required String temporaryPassword,
    required String apartmentName,
  }) {
    return sendEmail(
      to: email,
      subject: 'Welcome to JUMAA - Your Landlord Account',
      html:
          '''
<!DOCTYPE html>
<html>
<body style="font-family:Arial,sans-serif;background:#f5f7f6;padding:24px;">
  <div style="max-width:600px;margin:auto;background:#ffffff;padding:30px;border-radius:14px;">
    <h2 style="color:#0B3D2E;">Welcome to JUMAA</h2>

    <p>Hello <strong>${_escape(name)}</strong>,</p>

    <p>A landlord account has been created for you on JUMAA.</p>

    <h3 style="color:#0B3D2E;">Your account details</h3>

    <p><strong>Landlord ID:</strong> ${_escape(landlordId)}</p>
    <p><strong>Email:</strong> ${_escape(email)}</p>
    <p><strong>Phone:</strong> ${_escape(phone)}</p>
    <p><strong>Apartment:</strong> ${_escape(apartmentName)}</p>

    <div style="background:#eef5f1;padding:18px;border-radius:10px;margin:20px 0;">
      <p><strong>Temporary password</strong></p>
      <p style="font-size:22px;">
        <strong>${_escape(temporaryPassword)}</strong>
      </p>
    </div>

    <p>
      This temporary password is for first-time access only.
      You will be required to create a new password after signing in.
    </p>

    <p>Please keep your login credentials secure.</p>

    <p style="margin-top:30px;">
      Regards,<br>
      <strong>JUMAA</strong>
    </p>
  </div>
</body>
</html>
''',
    );
  }

  static Future<bool> sendPasswordResetCode({
    required String name,
    required String email,
    required String code,
  }) {
    return sendEmail(
      to: email,
      subject: 'JUMAA Password Reset Verification Code',
      html:
          '''
<!DOCTYPE html>
<html>
<body style="font-family:Arial,sans-serif;background:#f5f7f6;padding:24px;">
  <div style="max-width:600px;margin:auto;background:#ffffff;padding:30px;border-radius:14px;">
    <h2 style="color:#0B3D2E;">JUMAA Password Reset</h2>

    <p>Hello <strong>${_escape(name)}</strong>,</p>

    <p>
      We received a request to reset your JUMAA password.
      Use the verification code below:
    </p>

    <div style="background:#eef5f1;padding:22px;border-radius:10px;text-align:center;margin:25px 0;">
      <div style="font-size:32px;letter-spacing:8px;font-weight:bold;color:#0B3D2E;">
        ${_escape(code)}
      </div>
    </div>

    <p>
      Enter this code in the JUMAA app to continue resetting your password.
    </p>

    <p>
      If you did not request a password reset, you can safely ignore this email.
    </p>

    <p style="margin-top:30px;">
      Regards,<br>
      <strong>JUMAA</strong>
    </p>
  </div>
</body>
</html>
''',
    );
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pdezijwjfqyulkkuhoun.supabase.co',
    publishableKey: 'sb_publishable_wFuJsdho3es8WrD4vkqC_A_8MLx_0ft',
  );

  // Marketplace data is loaded by PublicUserPage when the
  // user opens Find an Apartment. Do not preload it here because
  // a slow network must never delay application startup.

  // Landlords are not required for the public marketplace.
  // Load them separately and never allow them to block startup.
  try {
    await OpenNestStore.loadLandlords().timeout(const Duration(seconds: 5));

    debugPrint(
      'STARTUP DEBUG: landlords loaded = '
      '${OpenNestStore.landlords.length}',
    );
  } on TimeoutException {
    debugPrint('STARTUP DEBUG: landlord loading timed out.');
  } catch (e) {
    debugPrint('STARTUP DEBUG: landlord loading failed: $e');
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

  String? _restoredRole;

  Map<String, dynamic>? _tenantProfile;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    try {
      // ----------------------------------------------------------
      // CHECK THE REAL SUPABASE SESSION FIRST
      // ----------------------------------------------------------
      final session = OpenNestStore.supabase.auth.currentSession;

      if (session == null) {
        if (mounted) {
          setState(() {
            _loggedIn = false;
            _loading = false;
          });
        }
        return;
      }

      final user = OpenNestStore.supabase.auth.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _loggedIn = false;
            _loading = false;
          });
        }
        return;
      }

      debugPrint('AUTH GATE: Existing Supabase session found.');
      debugPrint('AUTH GATE: user=${user.id}');
      debugPrint('AUTH GATE: email=${user.email}');

      // ----------------------------------------------------------
      // DETERMINE ACCOUNT ROLE
      // ----------------------------------------------------------
      String? role = user.userMetadata?['role']
          ?.toString()
          .toLowerCase()
          .trim();

      if (role == null || role.isEmpty) {
        try {
          final profile = await OpenNestStore.supabase
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();

          role = profile?['role']?.toString().toLowerCase().trim();

          debugPrint('AUTH GATE: profile role=$role');
        } catch (e) {
          debugPrint('AUTH GATE: Could not read profile role: $e');
        }
      }

      debugPrint('AUTH GATE: role=$role');

      // Remember the restored role so the correct dashboard
      // can be opened automatically after the app is restarted.
      _restoredRole = role;

      // ----------------------------------------------------------
      // VALIDATE TENANT SESSION
      // ----------------------------------------------------------
      if (role == 'tenant') {
        debugPrint('AUTH GATE: Restoring tenant session...');

        final tenantProfile = await OpenNestStore.loadTenantProfile();

        if (tenantProfile != null && mounted) {
          _tenantProfile = Map<String, dynamic>.from(tenantProfile);

          debugPrint(
            'AUTH GATE: Tenant session restored for '
            '${_tenantProfile?['full_name'] ?? _tenantProfile?['email'] ?? 'Tenant'}',
          );

          setState(() {
            _loggedIn = true;
            _loading = false;
          });

          return;
        }

        debugPrint('AUTH GATE: Tenant profile could not be loaded.');
      }

      // ----------------------------------------------------------
      // VALIDATE LANDLORD SESSION
      // ----------------------------------------------------------
      if (role == 'landlord') {
        final landlord = await OpenNestStore.loadLandlordProfile();

        if (landlord != null && mounted) {
          setState(() {
            _loggedIn = true;
            _loading = false;
          });
          return;
        }

        debugPrint('AUTH GATE: Landlord profile could not be loaded.');
      }

      // ----------------------------------------------------------
      // VALIDATE JUMAA OWNER SESSION
      // ----------------------------------------------------------
      if (role == 'jumaa_owner') {
        if (mounted) {
          setState(() {
            _loggedIn = true;
            _loading = false;
          });
          return;
        }
      }

      // ----------------------------------------------------------
      // VALIDATE PROPERTY OWNER SESSION
      // ----------------------------------------------------------
      if (role == 'owner' || role == null || role.isEmpty) {
        await OpenNestStore.loadOwners();

        if (mounted) {
          setState(() {
            _loggedIn = true;
            _loading = false;
          });
          return;
        }
      }

      // ----------------------------------------------------------
      // INVALID SESSION
      // ----------------------------------------------------------
      debugPrint(
        'AUTH GATE: Session exists but account could not be resolved.',
      );

      await OpenNestStore.supabase.auth.signOut();

      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('jumaa_logged_in');
      await prefs.remove('jumaa_logged_in_email');
      await prefs.remove('jumaa_logged_in_role');

      if (mounted) {
        setState(() {
          _loggedIn = false;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('AUTH GATE ERROR: $e');

      if (mounted) {
        setState(() {
          _loggedIn = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loggedIn) {
      // Restore tenants directly to the tenant dashboard.
      // Supabase keeps the authentication session alive until
      // the user explicitly signs out.
      if (_tenantProfile != null) {
        return TenantDashboardPage(tenantProfile: _tenantProfile!);
      }

      // Restore the JUMAA platform owner directly to the
      // JUMAA Owner Dashboard after restarting the app.
      if (_restoredRole == 'jumaa_owner') {
        return const JumaaOwnerDashboard();
      }

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
      showLogout: true,
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
            TextStyle(fontSize: 6, height: 0.8),
          ),
          iconTheme: WidgetStatePropertyAll(IconThemeData(size: 11)),
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
class _SubscriptionsPlaceholderPage extends StatefulWidget {
  const _SubscriptionsPlaceholderPage();

  @override
  State<_SubscriptionsPlaceholderPage> createState() =>
      _SubscriptionsPlaceholderPageState();
}

class _SubscriptionsPlaceholderPageState
    extends State<_SubscriptionsPlaceholderPage> {
  bool _loading = true;
  bool _paying = false;

  Property? _property;
  Map<String, dynamic>? _subscription;
  List<Map<String, dynamic>> _payments = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = OpenNestStore.supabase.auth.currentUser;

      if (user == null) {
        throw Exception('You are not signed in.');
      }

      Property? property;

      for (final candidate in OpenNestStore.properties) {
        if (candidate.ownerId == user.id) {
          property = candidate;
          break;
        }
      }

      if (property == null) {
        await OpenNestStore.loadPropertiesFromSupabase();

        for (final candidate in OpenNestStore.properties) {
          if (candidate.ownerId == user.id) {
            property = candidate;
            break;
          }
        }
      }

      if (property == null) {
        throw Exception('No property was found for your owner account.');
      }

      final response = await OpenNestStore.supabase
          .from('subscriptions')
          .select()
          .eq('owner_id', user.id)
          .eq('property_id', property.id)
          .maybeSingle();

      if (response == null) {
        throw Exception('No subscription exists for ${property.name}.');
      }

      final paymentResponse = await OpenNestStore.supabase
          .from('subscription_payments')
          .select()
          .eq('owner_id', user.id)
          .eq('property_id', property.id)
          .order('created_at', ascending: false)
          .limit(20);

      final payments = (paymentResponse as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      setState(() {
        _property = property;
        _subscription = Map<String, dynamic>.from(response);
        _payments = payments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int get _unitCount {
    final value = _subscription?['unit_count'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ??
        OpenNestStore.apartments
            .where((unit) => unit.propertyId == _property?.id)
            .length;
  }

  double get _monthlyAmount {
    final value = _subscription?['monthly_amount'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get _status {
    return (_subscription?['status']?.toString() ?? 'unknown').toUpperCase();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Color _statusColor() {
    switch (_status) {
      case 'ACTIVE':
        return Colors.green;
      case 'TRIAL':
        return Colors.orange;
      case 'EXPIRED':
      case 'PAST_DUE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _payWithPaystack() async {
    if (_paying) return;

    final user = OpenNestStore.supabase.auth.currentUser;

    if (user == null) {
      _showMessage('You are not signed in.', isError: true);
      return;
    }

    final property = _property;

    if (property == null) {
      _showMessage('No property is available for payment.', isError: true);
      return;
    }

    if (_monthlyAmount <= 0) {
      _showMessage(
        'The subscription has an invalid monthly amount.',
        isError: true,
      );
      return;
    }

    final email = user.email?.trim();

    if (email == null || email.isEmpty) {
      _showMessage(
        'Your account does not have an email address for Paystack.',
        isError: true,
      );
      return;
    }

    setState(() {
      _paying = true;
    });

    try {
      final response = await OpenNestStore.supabase.functions.invoke(
        'initialize-subscription-payment',
        body: {
          'owner_id': user.id,
          'property_id': property.id,
          'amount': _monthlyAmount,
          'email': email,
        },
      );

      final data = response.data;

      if (response.status != 200 || data is! Map || data['success'] != true) {
        throw Exception(
          data is Map && data['error'] != null
              ? data['error'].toString()
              : 'Could not initialize the Paystack payment.',
        );
      }

      final authorizationUrl = data['authorization_url']?.toString();

      if (authorizationUrl == null || authorizationUrl.trim().isEmpty) {
        throw Exception('Paystack did not return a checkout URL.');
      }

      final uri = Uri.tryParse(authorizationUrl);

      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw Exception('Paystack returned an invalid checkout URL.');
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open Paystack checkout.');
      }

      if (!mounted) return;

      _showMessage('Paystack checkout opened. Complete the payment there.');

      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        await _loadSubscription();
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Payment could not be started: '
        '${e.toString().replaceFirst('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _paying = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Subscriptions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _paying ? null : _loadSubscription,
            icon: const Icon(Icons.refresh),
          ),
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
              Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Unable to load subscription',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadSubscription,
                icon: const Icon(Icons.refresh),
                label: const Text('TRY AGAIN'),
              ),
            ],
          ),
        ),
      );
    }

    final property = _property;
    final subscription = _subscription;

    if (property == null || subscription == null) {
      return const Center(
        child: Text('No subscription information available.'),
      );
    }

    final statusColor = _statusColor();

    return RefreshIndicator(
      onRefresh: _loadSubscription,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    child: const Icon(Icons.apartment, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
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
                        const SizedBox(height: 4),
                        Text(
                          '$_unitCount units',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'JUMAA SUBSCRIPTION',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      const Expanded(child: Text('Current status')),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 28),

                  _infoRow(
                    'Monthly plan',
                    'KES ${_monthlyAmount.toStringAsFixed(0)}',
                  ),

                  const SizedBox(height: 12),

                  _infoRow('Units covered', _unitCount.toString()),

                  const SizedBox(height: 12),

                  _infoRow(
                    'Trial ends',
                    _formatDate(subscription['trial_ends_at']),
                  ),

                  const SizedBox(height: 12),

                  _infoRow(
                    'Subscription starts',
                    _formatDate(subscription['subscription_starts_at']),
                  ),

                  const SizedBox(height: 12),

                  _infoRow(
                    'Subscription ends',
                    _formatDate(subscription['subscription_ends_at']),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscription payment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pay your JUMAA subscription securely through Paystack.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Amount to pay',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          'KES ${_monthlyAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _paying || _monthlyAmount <= 0
                          ? null
                          : _payWithPaystack,
                      icon: _paying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_outline),
                      label: Text(
                        _paying
                            ? 'OPENING PAYSTACK...'
                            : _status == 'ACTIVE'
                            ? 'RENEW WITH PAYSTACK'
                            : 'PAY WITH PAYSTACK',
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Only the property owner/admin can make '
                    'subscription payments.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _payments.isEmpty
                          ? null
                          : _showSubscriptionHistory,
                      icon: const Icon(Icons.history),
                      label: const Text('VIEW SUBSCRIPTION HISTORY'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_payments.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildLatestReceipt(context),
          ],
        ],
      ),
    );
  }

  String _receiptNumber(Map<String, dynamic> payment) {
    final reference = payment['reference']?.toString() ?? '';
    final clean = reference.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

    if (clean.isEmpty) {
      return 'JUMAA-RCP-${payment['id']?.toString().substring(0, 8) ?? '00000000'}';
    }

    final suffix = clean.length > 12
        ? clean.substring(clean.length - 12)
        : clean;

    return 'JUMAA-RCP-$suffix';
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '—';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day} ${months[date.month - 1]} ${date.year} '
        '$hour:$minute $period';
  }

  Widget _buildLatestReceipt(BuildContext context) {
    final payment = _payments.first;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'LATEST RECEIPT',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PAID',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Divider(),

            const SizedBox(height: 14),

            _infoRow('Receipt number', _receiptNumber(payment)),

            const SizedBox(height: 12),

            _infoRow(
              'Payment date',
              _formatDateTime(payment['paid_at'] ?? payment['created_at']),
            ),

            const SizedBox(height: 12),

            _infoRow(
              'Amount paid',
              'KES ${_paymentAmount(payment).toStringAsFixed(0)}',
            ),

            const SizedBox(height: 12),

            _infoRow(
              'Payment method',
              (payment['payment_method']?.toString() ?? '—').toUpperCase(),
            ),

            const SizedBox(height: 12),

            _infoRow('Reference', payment['reference']?.toString() ?? '—'),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showReceipt(payment),
                icon: const Icon(Icons.receipt_long),
                label: const Text('VIEW RECEIPT'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _paymentAmount(Map<String, dynamic> payment) {
    return double.tryParse(payment['amount']?.toString() ?? '') ?? 0;
  }

  int _paymentMonths(Map<String, dynamic> payment) {
    return int.tryParse(payment['months_covered']?.toString() ?? '') ?? 0;
  }

  void _showSubscriptionHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscription History',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    '${_property?.name ?? 'Property'} • '
                    '${_payments.length} payment'
                    '${_payments.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 18),

                  Expanded(
                    child: _payments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 56,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No payment history yet.',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _payments.length,
                            itemBuilder: (context, index) {
                              final payment = _payments[index];

                              final amount = _paymentAmount(payment);

                              final months = _paymentMonths(payment);

                              final status =
                                  payment['status']?.toString().toUpperCase() ??
                                  '—';

                              final paymentDate =
                                  payment['paid_at'] ?? payment['created_at'];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Card(
                                  elevation: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              child: Icon(
                                                status == 'SUCCESS'
                                                    ? Icons.check
                                                    : Icons.receipt_long,
                                              ),
                                            ),

                                            const SizedBox(width: 12),

                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _formatDate(paymentDate),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    '$months month'
                                                    '${months == 1 ? '' : 's'} • '
                                                    'Paystack',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            Text(
                                              'KES ${amount.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 14),

                                        const Divider(),

                                        const SizedBox(height: 10),

                                        Row(
                                          children: [
                                            Icon(
                                              status == 'SUCCESS'
                                                  ? Icons.verified
                                                  : Icons.info_outline,
                                              size: 17,
                                              color: status == 'SUCCESS'
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 7),
                                            Text(
                                              status == 'SUCCESS'
                                                  ? 'Payment successful'
                                                  : status,
                                              style: TextStyle(
                                                color: status == 'SUCCESS'
                                                    ? Colors.green
                                                    : Colors.grey,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 10),

                                        Text(
                                          'Ref: ${payment['reference'] ?? '—'}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),

                                        const SizedBox(height: 12),

                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              _showReceipt(payment);
                                            },
                                            icon: const Icon(
                                              Icons.receipt_long,
                                            ),
                                            label: const Text('VIEW RECEIPT'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReceipt(Map<String, dynamic> payment) {
    final amount = _paymentAmount(payment);
    final months = _paymentMonths(payment);
    final status = payment['status']?.toString().toUpperCase() ?? '—';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            child: Icon(
                              status == 'SUCCESS'
                                  ? Icons.check
                                  : Icons.receipt_long,
                              size: 30,
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'JUMAA',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'SUBSCRIPTION RECEIPT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status == 'SUCCESS'
                                  ? '✓ PAYMENT SUCCESSFUL'
                                  : status,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Divider(),

                    const SizedBox(height: 14),

                    _receiptRow('Receipt number', _receiptNumber(payment)),

                    _receiptRow(
                      'Payment date',
                      _formatDateTime(
                        payment['paid_at'] ?? payment['created_at'],
                      ),
                    ),

                    _receiptRow('Property', _property?.name ?? '—'),

                    _receiptRow(
                      'Units covered',
                      payment['units_count']?.toString() ??
                          _unitCount.toString(),
                    ),

                    _receiptRow('Billing plan', 'Monthly JUMAA subscription'),

                    _receiptRow(
                      'Months covered',
                      '$months month${months == 1 ? '' : 's'}',
                    ),

                    _receiptRow(
                      'Payment method',
                      (payment['payment_method']?.toString() ?? '—')
                          .toUpperCase(),
                    ),

                    _receiptRow(
                      'Transaction reference',
                      payment['reference']?.toString() ?? '—',
                    ),

                    const SizedBox(height: 18),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'AMOUNT PAID',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'KES ${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'SUBSCRIPTION PERIOD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _periodBox(
                            'STARTS',
                            _formatDate(
                              _subscription?['subscription_starts_at'],
                            ),
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward),
                        ),

                        Expanded(
                          child: _periodBox(
                            'ENDS',
                            _formatDate(_subscription?['subscription_ends_at']),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    const Divider(),

                    const SizedBox(height: 12),

                    Center(
                      child: Text(
                        'This receipt confirms successful payment '
                        'of the JUMAA subscription.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('CLOSE'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      child: SizedBox(
        height: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, size: 8),
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
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        leading: Icon(icon, size: 14),
        title: Text(
          title,
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 8),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: SizedBox(
        height: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
          child: Row(
            children: [
              Icon(icon, size: 8),
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
  bool _uploading = false;

  Future<void> _addPhotos() async {
    if (_uploading) return;

    try {
      final picker = ImagePicker();

      final pickedFiles = await picker.pickMultiImage(imageQuality: 85);

      if (pickedFiles.isEmpty) {
        return;
      }

      setState(() {
        _uploading = true;
      });

      final existingUrls = List<String>.from(widget.property.imagePaths);

      for (final file in pickedFiles) {
        final extension = file.path.contains('.')
            ? file.path.split('.').last.toLowerCase()
            : 'jpg';

        final safeExtension = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(extension)
            ? extension
            : 'jpg';

        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${existingUrls.length}.$safeExtension';

        final storagePath = '${widget.property.id}/$fileName';

        final bytes = await file.readAsBytes();

        String contentType = 'image/jpeg';

        if (safeExtension == 'png') {
          contentType = 'image/png';
        } else if (safeExtension == 'webp') {
          contentType = 'image/webp';
        } else if (safeExtension == 'heic') {
          contentType = 'image/heic';
        } else if (safeExtension == 'heif') {
          contentType = 'image/heif';
        }

        await OpenNestStore.supabase.storage
            .from('property-images')
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(upsert: true, contentType: contentType),
            );

        final publicUrl = OpenNestStore.supabase.storage
            .from('property-images')
            .getPublicUrl(storagePath);

        existingUrls.add(publicUrl);
      }

      await OpenNestStore.supabase
          .from('properties')
          .update({
            'image_paths': existingUrls,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.property.id);

      widget.property.imagePaths = existingUrls;

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${pickedFiles.length} photo${pickedFiles.length == 1 ? '' : 's'} uploaded successfully.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('PROPERTY PHOTO UPLOAD ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  String? _storagePathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);

      const marker = '/storage/v1/object/public/property-images/';

      final index = uri.path.indexOf(marker);

      if (index == -1) {
        return null;
      }

      return Uri.decodeComponent(uri.path.substring(index + marker.length));
    } catch (_) {
      return null;
    }
  }

  Future<void> _deletePhoto(String photoUrl) async {
    if (_uploading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Photo?'),
          content: const Text(
            'This photo will be removed from the property gallery.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final updatedUrls = List<String>.from(widget.property.imagePaths)
        ..remove(photoUrl);

      final storagePath = _storagePathFromUrl(photoUrl);

      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          await OpenNestStore.supabase.storage.from('property-images').remove([
            storagePath,
          ]);
        } catch (e) {
          debugPrint('PROPERTY PHOTO STORAGE DELETE ERROR: $e');
        }
      }

      await OpenNestStore.supabase
          .from('properties')
          .update({
            'image_paths': updatedUrls,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.property.id);

      widget.property.imagePaths = updatedUrls;

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo deleted successfully.')),
      );
    } catch (e) {
      debugPrint('PROPERTY PHOTO DELETE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _photoThumbnail(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return Container(
            width: 90,
            height: 90,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_outlined),
          );
        },
      );
    }

    return Image.file(
      File(path),
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return Container(
          width: 90,
          height: 90,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }

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

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _uploading ? null : _addPhotos,
              icon: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _uploading ? 'UPLOADING PHOTOS...' : 'ADD PHOTOS',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 18),

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
                    const SizedBox(height: 6),
                    Text(
                      'Tap ADD PHOTOS to select images from your phone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ...images.map(
              (path) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _photoThumbnail(path),
                  ),
                  title: const Text(
                    'Property Photo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    path.startsWith('http')
                        ? 'Uploaded to Supabase Storage'
                        : path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: () => _deletePhoto(path),
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
  bool _bookingSubmitting = false;
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

  Future<void> _startChat() async {
    try {
      final response = await OpenNestStore.supabase
          .from('properties')
          .select('owner_id, landlord_id')
          .eq('id', widget.property.id)
          .maybeSingle();

      final landlordId =
          response?['landlord_id']?.toString() ??
          response?['owner_id']?.toString() ??
          widget.property.ownerId;

      debugPrint('CHAT DEBUG: property=${widget.property.id}');
      debugPrint('CHAT DEBUG: ownerId=${response?['owner_id']}');
      debugPrint('CHAT DEBUG: landlordId=${response?['landlord_id']}');
      debugPrint('CHAT DEBUG: resolvedLandlordId=$landlordId');

      if (landlordId.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No landlord is assigned to this apartment.'),
          ),
        );
        return;
      }

      final landlord = await OpenNestStore.loadLandlordById(landlordId);

      if (!mounted) return;

      if (landlord == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find the landlord for this apartment.'),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatListScreen(
            landlordId: landlord.id,
            landlordName: landlord.fullName,
            propertyId: widget.property.id,
            propertyName: widget.property.name,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open landlord chat: $e')),
      );
    }
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
                          onPressed: _bookingSubmitting
                              ? null
                              : () async {
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
                                        content: Text(
                                          'Please select a vacant unit.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final selectedApartment = availableUnits
                                      .firstWhere(
                                        (unit) => unit.number == selectedUnit,
                                        orElse: () => availableUnits.first,
                                      );

                                  try {
                                    setState(() {
                                      _bookingSubmitting = true;
                                    });

                                    final bookingService = BookingService();

                                    debugPrint(
                                      'BOOKING UI: submitting booking request...',
                                    );

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
                                  } catch (e, stackTrace) {
                                    debugPrint('BOOKING UI ERROR: $e');
                                    debugPrint('BOOKING UI STACK: $stackTrace');

                                    if (context.mounted) {
                                      setState(() {
                                        _bookingSubmitting = false;
                                      });
                                    }

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

  @override
  void initState() {
    super.initState();
    _loadMarketplace();
  }

  Future<void> _loadMarketplace() async {
    if (mounted) {}

    try {
      await OpenNestStore.loadMarketplaceDataFromSupabase();

      if (!mounted) return;

      debugPrint(
        'APARTMENTS PAGE: marketplace loaded: '
        '${OpenNestStore.properties.length} properties, '
        '${OpenNestStore.apartments.length} units.',
      );

      setState(() {});
    } catch (e) {
      debugPrint('APARTMENTS PAGE LOAD ERROR: $e');

      if (!mounted) return;
    }
  }

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
        side: BorderSide(color: primary.withValues(alpha: 0.08)),
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

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return SizedBox(
        height: 118,
        width: 105,
        child: Image.network(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return _propertyPlaceholder();
          },
        ),
      );
    }

    return SizedBox(
      height: 118,
      width: 105,
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
      height: 118,
      width: 105,
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
  final Map<String, dynamic>? tenantProfile;

  const PaymentsPage({super.key, this.tenantProfile});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _payments = [];

  String get _tenantId {
    return widget.tenantProfile?['id']?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_tenantId.isEmpty) {
        throw Exception('Tenant profile is missing.');
      }

      final response = await OpenNestStore.supabase
          .from('payments')
          .select('''
            id,
            tenant_id,
            property_id,
            unit_id,
            amount,
            payment_method,
            payment_destination,
            reference,
            status,
            payment_date,
            due_date,
            created_at
          ''')
          .eq('tenant_id', _tenantId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _payments = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });

      debugPrint(
        'TENANT PAYMENTS: loaded ${_payments.length} payment(s) '
        'for tenant $_tenantId',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });

      debugPrint('TENANT PAYMENT LOADING ERROR: $e');
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

    debugPrint(
      'MARKETPLACE DEBUG: properties response count = ${response.length}',
    );
    for (final row in response) {
      debugPrint(
        'MARKETPLACE PROPERTY: '
        'id=${row['id']} '
        'name=${row['name']} '
        'county=${row['county']} '
        'subcounty=${row['subcounty']} '
        'location=${row['location']}',
      );
    }

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
          ownerId:
              row['owner_id']?.toString() ??
              row['landlord_id']?.toString() ??
              '',
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
          imagePaths: row['image_paths'] is List
              ? List<String>.from(
                  (row['image_paths'] as List)
                      .map((item) => item.toString())
                      .where((item) => item.trim().isNotEmpty),
                )
              : const [],
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

    debugPrint('MARKETPLACE DEBUG: units response count = ${response.length}');
    for (final row in response) {
      debugPrint(
        'MARKETPLACE UNIT: '
        'id=${row['id']} '
        'unit=${row['unit_number']} '
        'property_id=${row['property_id']} '
        'type=${row['unit_type']} '
        'rent=${row['monthly_rent']} '
        'status=${row['status']}',
      );
    }

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
          propertyName:
              prefs.getString('landlord_${i}_propertyName') ??
              prefs.getString('landlord_${i}_apartment') ??
              '',
          propertyId:
              prefs.getString('landlord_${i}_propertyId') ??
              prefs.getString('landlord_${i}_apartmentId') ??
              '',
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
      await prefs.setString(
        'landlord_${i}_propertyName',
        landlord.propertyName,
      );
      await prefs.setString('landlord_${i}_propertyId', landlord.propertyId);
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

    try {
      final landlordRow = await supabase
          .from('landlords')
          .select('id, full_name, email, phone')
          .eq('id', user.id)
          .maybeSingle();

      if (landlordRow == null) {
        debugPrint(
          'LANDLORD PROFILE: No landlord found for auth user ${user.id}',
        );
        return null;
      }

      final propertyRow = await supabase
          .from('properties')
          .select('id, name')
          .eq('landlord_id', user.id)
          .maybeSingle();

      final landlord = Landlord(
        id: landlordRow['id']?.toString() ?? user.id,
        fullName: landlordRow['full_name']?.toString() ?? '',
        email: landlordRow['email']?.toString() ?? user.email ?? '',
        phone: landlordRow['phone']?.toString() ?? '',
        temporaryPassword: '',
        mustResetPassword: false,
        propertyName: propertyRow?['name']?.toString() ?? '',
        propertyId: propertyRow?['id']?.toString() ?? '',
      );

      landlords
        ..clear()
        ..add(landlord);

      debugPrint(
        'LANDLORD PROFILE: ${landlord.fullName} | '
        '${landlord.email} | '
        '${landlord.propertyName} | '
        '${landlord.propertyId}',
      );

      return landlord;
    } catch (e) {
      debugPrint('LANDLORD PROFILE LOAD ERROR: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> loadTenantProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      debugPrint('TENANT PROFILE: No authenticated user.');
      return null;
    }

    try {
      final tenantRow = await supabase
          .from('tenants')
          .select('''
            id,
            auth_user_id,
            property_id,
            unit_id,
            full_name,
            email,
            phone,
            account_status,
            move_in_date,
            properties (
              id,
              name,
              description,
              location,
              address,
              phone,
              email,
              county,
              subcounty
            ),
            units (
              id,
              unit_number,
              unit_type,
              rent,
              monthly_rent,
              status
            )
          ''')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (tenantRow == null) {
        debugPrint('TENANT PROFILE: No tenant found for auth user ${user.id}');
        return null;
      }

      debugPrint(
        'TENANT PROFILE: '
        '${tenantRow['full_name']} | '
        '${tenantRow['email']} | '
        'property=${tenantRow['property_id']} | '
        'unit=${tenantRow['unit_id']}',
      );

      return Map<String, dynamic>.from(tenantRow);
    } catch (e) {
      debugPrint('TENANT PROFILE LOAD ERROR: $e');
      return null;
    }
  }

  static Future<Landlord?> loadLandlordById(String id) async {
    final row = await supabase
        .from('landlords')
        .select('id, full_name, email, phone')
        .eq('id', id)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    final propertyRow = await supabase
        .from('properties')
        .select('id, name')
        .eq('landlord_id', id)
        .maybeSingle();

    return Landlord(
      id: row['id']?.toString() ?? id,
      fullName: row['full_name']?.toString() ?? '',
      email: row['email']?.toString() ?? '',
      phone: row['phone']?.toString() ?? '',
      temporaryPassword: '',
      mustResetPassword: false,
      propertyName: propertyRow?['name']?.toString() ?? '',
      propertyId: propertyRow?['id']?.toString() ?? '',
    );
  }
}

// ============================================================
// JUMAA - TENANT DASHBOARD
// ============================================================

class TenantDashboardPage extends StatefulWidget {
  final Map<String, dynamic> tenantProfile;

  const TenantDashboardPage({super.key, required this.tenantProfile});

  @override
  State<TenantDashboardPage> createState() => _TenantDashboardPageState();
}

class _TenantDashboardPageState extends State<TenantDashboardPage> {
  int currentIndex = 0;

  Map<String, dynamic> get tenant {
    return widget.tenantProfile;
  }

  Map<String, dynamic> get property {
    final value = tenant['properties'];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  Map<String, dynamic> get unit {
    final value = tenant['units'];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  String _value(dynamic value, [String fallback = 'Not provided']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  void _selectPage(int index) {
    if (!mounted) return;

    setState(() {
      currentIndex = index;
    });
  }

  List<Widget> get pages => [
    _buildDashboardPage(),
    ChatListScreen(
      tenantProfile: widget.tenantProfile,
      propertyId: widget.tenantProfile['property_id']?.toString(),
      propertyName: property['name']?.toString(),
    ),
    const TenantAnnouncementsPage(),
    TenantNotificationsPage(tenantProfile: widget.tenantProfile),
    PaymentsPage(tenantProfile: widget.tenantProfile),
    SettingsPage(
      isDarkMode: Theme.of(context).brightness == Brightness.dark,
      onDarkModeChanged: (enabled) {
        final state = context.findAncestorStateOfType<_ApartmentAppState>();

        state?._setDarkMode(enabled);
      },
      showLogout: true,
    ),
  ];

  Widget _buildDashboardPage() {
    final tenantName = _value(tenant['full_name'], 'Tenant');
    final propertyName = _value(property['name'], 'My Home');
    final unitNumber = _value(unit['unit_number'], '');
    final unitType = _value(unit['unit_type'], '');
    final rent = _value(unit['monthly_rent'] ?? unit['rent'], '');
    final location = _value(property['location'], '');
    final accountStatus = _value(tenant['account_status'], 'active');

    final hasUnit = unitNumber.isNotEmpty;
    final hasRent = rent.isNotEmpty;
    final hasLocation = location.isNotEmpty;
    final hasUnitType = unitType.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Home',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigator = Navigator.of(context);

              await OpenNestStore.supabase.auth.signOut();

              if (!mounted) return;

              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('jumaa_logged_in');
              await prefs.remove('jumaa_logged_in_email');
              await prefs.remove('jumaa_logged_in_role');

              if (!mounted) return;

              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const JUMAALoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final profile = await OpenNestStore.loadTenantProfile();

          if (!mounted || profile == null) return;

          setState(() {
            widget.tenantProfile
              ..clear()
              ..addAll(profile);
          });
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $tenantName 👋',
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0B3D2E),
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        "Here's what's happening with your home.",
                        style: TextStyle(color: Colors.black54, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ----------------------------------------------------------
            // MY HOME
            // ----------------------------------------------------------
            Card(
              elevation: 2,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F3EE),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.apartment_rounded,
                            color: Color(0xFF0B3D2E),
                            size: 29,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MY HOME',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                propertyName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    if (hasUnit)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F8F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.door_front_door_outlined,
                              color: Color(0xFF0B3D2E),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'YOUR UNIT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    unitNumber,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (hasUnitType) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      unitType,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _emptyHomeMessage(
                        Icons.home_work_outlined,
                        'No unit assigned yet',
                        'Your property manager has not assigned a unit to this account.',
                      ),

                    if (hasLocation) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ----------------------------------------------------------
            // RENT
            // ----------------------------------------------------------
            Card(
              elevation: 1,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _selectPage(4),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F3EE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.payments_outlined,
                          color: Color(0xFF0B3D2E),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RENT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasRent ? rent : 'Rent details unavailable',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: hasRent
                                    ? const Color(0xFF0B3D2E)
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ----------------------------------------------------------
            // ACCOUNT STATUS
            // ----------------------------------------------------------
            Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 19,
                  color: Color(0xFF0B3D2E),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Account',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    accountStatus.toUpperCase(),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            const Text(
              'Tenant Services',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _serviceCard(
                    icon: Icons.payments_outlined,
                    title: 'Payments',
                    subtitle: 'Rent & history',
                    onTap: () => _selectPage(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _serviceCard(
                    icon: Icons.build_outlined,
                    title: 'Maintenance',
                    subtitle: 'Request repairs',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MaintenancePage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _serviceCard(
                    icon: Icons.chat_bubble_outline,
                    title: 'Messages',
                    subtitle: 'Contact landlord',
                    onTap: () => _selectPage(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _serviceCard(
                    icon: Icons.notifications_none,
                    title: 'Notifications',
                    subtitle: 'Stay updated',
                    onTap: () => _selectPage(3),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _serviceCard(
              icon: Icons.campaign_outlined,
              title: 'Announcements',
              subtitle: 'Apartment updates',
              onTap: () => _selectPage(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHomeMessage(IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black45),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final accentColors = <String, Color>{
      'Payments': const Color(0xFF4F46E5),
      'Maintenance': const Color(0xFFF97316),
      'Messages': const Color(0xFF0EA5E9),
      'Notifications': const Color(0xFFE11D48),
      'Announcements': const Color(0xFF16A34A),
    };

    final accent = accentColors[title] ?? const Color(0xFF6366F1);

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shadowColor: accent.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 21, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: accent.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboardPage(),
      ChatListScreen(
        tenantProfile: widget.tenantProfile,
        propertyId: widget.tenantProfile['property_id']?.toString(),
        propertyName: property['name']?.toString(),
      ),
      const TenantAnnouncementsPage(),
      TenantNotificationsPage(tenantProfile: widget.tenantProfile),
      PaymentsPage(tenantProfile: widget.tenantProfile),
      SettingsPage(
        isDarkMode: Theme.of(context).brightness == Brightness.dark,
        onDarkModeChanged: (enabled) {
          final state = context.findAncestorStateOfType<_ApartmentAppState>();

          state?._setDarkMode(enabled);
        },
        showLogout: true,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: const NavigationBarThemeData(
          height: 62,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
          ),
          iconTheme: WidgetStatePropertyAll(IconThemeData(size: 21)),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: _selectPage,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Announcements',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_none),
              selectedIcon: Icon(Icons.notifications),
              label: 'Notifications',
            ),
            NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Payments',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TENANT ANNOUNCEMENTS
// ============================================================

class TenantAnnouncementsPage extends StatelessWidget {
  const TenantAnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Announcements',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.campaign_outlined),
              title: Text('No announcements yet'),
              subtitle: Text(
                'Apartment announcements from management will appear here.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TENANT NOTIFICATIONS
// ============================================================

class TenantNotificationsPage extends StatefulWidget {
  final Map<String, dynamic> tenantProfile;

  const TenantNotificationsPage({super.key, required this.tenantProfile});

  @override
  State<TenantNotificationsPage> createState() =>
      _TenantNotificationsPageState();
}

class _TenantNotificationsPageState extends State<TenantNotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  String get _propertyId =>
      widget.tenantProfile['property_id']?.toString() ?? '';

  String get _tenantId => widget.tenantProfile['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (_propertyId.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final response = await OpenNestStore.supabase
          .from('notifications')
          .select(
            'id, user_id, property_id, title, message, type, '
            'is_read, created_at, sender_type, sender_name',
          )
          .eq('property_id', _propertyId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      debugPrint('TENANT NOTIFICATIONS LOAD ERROR: $e');

      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load notifications: $e')),
      );
    }
  }

  Future<void> _createNotification() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Notification'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Water interruption',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Write your notification...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty ||
                    messageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter both a title and message.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, true);
              },
              child: const Text('Post Notification'),
            ),
          ],
        );
      },
    );

    if (result != true) {
      titleController.dispose();
      messageController.dispose();
      return;
    }

    if (_propertyId.isEmpty || _tenantId.isEmpty) {
      titleController.dispose();
      messageController.dispose();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your apartment information is missing.')),
      );
      return;
    }

    try {
      await OpenNestStore.supabase.from('notifications').insert({
        'user_id': OpenNestStore.supabase.auth.currentUser?.id,
        'property_id': _propertyId,
        'title': titleController.text.trim(),
        'message': messageController.text.trim(),
        'type': 'general',
        'is_read': false,
        'sender_type': 'tenant',
        'sender_name':
            widget.tenantProfile['full_name']?.toString() ??
            widget.tenantProfile['name']?.toString() ??
            'Tenant',
      });

      titleController.dispose();
      messageController.dispose();

      await _loadNotifications();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notification posted. Everyone in your apartment can see it.',
          ),
        ),
      );
    } catch (e) {
      titleController.dispose();
      messageController.dispose();

      debugPrint('TENANT NOTIFICATION CREATE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create notification: $e')),
      );
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNotification,
        icon: const Icon(Icons.add),
        label: const Text('Add Notification'),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.campaign_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Apartment Notifications',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Tenants and landlords can post important '
                                  'updates. Everyone in this apartment can '
                                  'see them.',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Recent Notifications',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  if (_notifications.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_none_outlined,
                              size: 55,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No notifications yet',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Be the first to post an important update '
                              'for your apartment.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._notifications.map((notification) {
                      final title = notification['title']?.toString() ?? '';
                      final message = notification['message']?.toString() ?? '';
                      final createdAt = notification['created_at'];

                      final isMine =
                          notification['user_id']?.toString() ==
                          OpenNestStore.supabase.auth.currentUser?.id;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: const CircleAvatar(
                            child: Icon(Icons.notifications_outlined),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(message),
                                const SizedBox(height: 7),
                                Text(
                                  '${isMine ? 'You' : 'Apartment member'}'
                                  ' • ${_formatDate(createdAt)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
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

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _deleteTenant(tenant);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Tenant'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteTenant(Tenant tenant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Tenant?'),
          content: Text(
            'Are you sure you want to permanently delete '
            '${tenant.name}?\n\n'
            'This will remove the tenant from this owner account '
            'and delete their JUMAA account access.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleting tenant...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final response = await OpenNestStore.supabase.functions.invoke(
        'delete-tenant-account',
        body: {'tenant_id': tenant.id, 'email': tenant.email},
      );

      final data = response.data;

      if (response.status != 200 || data is! Map || data['success'] != true) {
        throw Exception(
          data is Map && data['error'] != null
              ? data['error'].toString()
              : 'Tenant could not be deleted.',
        );
      }

      // Remove it immediately from the current owner's screen.
      if (!mounted) return;

      setState(() {
        tenants.removeWhere((item) => item.id == tenant.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tenant.name} deleted successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      // Re-sync from Supabase so it cannot return after refresh.
      await _loadTenants();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete tenant: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

                            final tenantId =
                                tenantResponse['id']?.toString() ?? '';

                            if (tenantId.isEmpty) {
                              throw Exception(
                                'Tenant was created but no tenant ID was returned.',
                              );
                            }

                            // Create the tenant's Supabase Auth account,
                            // tenant profile and send login credentials.
                            final accountResponse = await OpenNestStore
                                .supabase
                                .functions
                                .invoke(
                                  'create-tenant-account',
                                  body: {
                                    'tenant_id': tenantId,
                                    'full_name': name,
                                    'email': email,
                                    'phone': phone,
                                    'apartment': unitNumber,
                                  },
                                );

                            final accountData = accountResponse.data;

                            if (accountResponse.status != 200) {
                              String accountError =
                                  'Tenant account could not be created.';

                              if (accountData is Map &&
                                  accountData['error'] != null) {
                                accountError = accountData['error'].toString();
                              }

                              throw Exception(accountError);
                            }

                            if (accountData is Map &&
                                accountData['email_sent'] == false) {
                              throw Exception(
                                'Tenant account was created, but the invitation email could not be sent.',
                              );
                            }

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

      if (landlord.mustResetPassword) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LandlordResetPasswordPage(landlord: landlord),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LandlordDashboardPage(
            landlord: landlord,
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
            onDarkModeChanged: (enabled) {
              final state = context
                  .findAncestorStateOfType<_ApartmentAppState>();

              state?._setDarkMode(enabled);
            },
            onLogout: () async {
              await OpenNestStore.supabase.auth.signOut();

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const JUMAAWelcomePage()),
                (route) => false,
              );
            },
          ),
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
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    cursorColor: Colors.black,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Colors.grey,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    cursorColor: Colors.black,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.grey,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
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
                          color: Colors.grey,
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
  bool _isSaving = false;

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

    setState(() {
      _isSaving = true;
    });

    try {
      final response = await OpenNestStore.supabase.functions.invoke(
        'update-landlord-password',
        body: {'new_password': password},
      );

      final data = response.data;

      if (data is! Map || data['success'] != true) {
        throw Exception(
          data is Map && data['error'] != null
              ? data['error'].toString()
              : 'Could not update your password.',
        );
      }

      widget.landlord.temporaryPassword = password;
      widget.landlord.mustResetPassword = false;

      await OpenNestStore.saveLandlords();

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LandlordDashboardPage(
            landlord: widget.landlord,
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
            onDarkModeChanged: (enabled) {
              final state = context
                  .findAncestorStateOfType<_ApartmentAppState>();
              state?._setDarkMode(enabled);
            },
            onLogout: () async {
              await OpenNestStore.supabase.auth.signOut();

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const JUMAAWelcomePage()),
                (route) => false,
              );
            },
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                    onPressed: _isSaving ? null : _resetPassword,
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

    String? selectedPropertyId;

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
                      initialValue: selectedPropertyId,
                      decoration: const InputDecoration(
                        labelText: 'Assign property',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                      items: OpenNestStore.properties
                          .map(
                            (property) => DropdownMenuItem<String>(
                              value: property.id,
                              child: Text(property.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedPropertyId = value;
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
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    final phone = phoneController.text.trim();

                    if (name.isEmpty ||
                        email.isEmpty ||
                        phone.isEmpty ||
                        selectedPropertyId == null) {
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

                    final selectedProperty = OpenNestStore.properties
                        .firstWhere(
                          (property) => property.id == selectedPropertyId,
                        );

                    // ------------------------------------------------------
                    // Create the REAL landlord Supabase Auth account.
                    // The Edge Function generates the actual temporary
                    // password and sends the invitation email.
                    // ------------------------------------------------------
                    final accountResponse = await OpenNestStore
                        .supabase
                        .functions
                        .invoke(
                          'create-landlord-account',
                          body: {
                            'full_name': name,
                            'email': email,
                            'phone': phone,
                            'property_id': selectedProperty.id,
                            'property_name': selectedProperty.name,
                          },
                        );

                    final accountData = accountResponse.data;

                    if (accountResponse.status != 200) {
                      String accountError =
                          'Landlord account could not be created.';

                      if (accountData is Map && accountData['error'] != null) {
                        accountError = accountData['error'].toString();
                      }

                      throw Exception(accountError);
                    }

                    if (accountData is! Map || accountData['success'] != true) {
                      throw Exception(
                        accountData is Map && accountData['error'] != null
                            ? accountData['error'].toString()
                            : 'Landlord account could not be created.',
                      );
                    }

                    final temporaryPassword =
                        accountData['temporary_password']?.toString() ?? '';

                    if (temporaryPassword.isEmpty) {
                      throw Exception(
                        'Landlord account was created but no temporary password was returned.',
                      );
                    }

                    final authUserId =
                        accountData['auth_user_id']?.toString() ?? '';

                    if (authUserId.isEmpty) {
                      throw Exception(
                        'Landlord account was created but no Auth user ID was returned.',
                      );
                    }

                    final landlord = Landlord(
                      id: authUserId,
                      fullName: name,
                      email: email,
                      phone: phone,
                      temporaryPassword: temporaryPassword,
                      mustResetPassword: true,
                      propertyName: selectedProperty.name,
                      propertyId: selectedProperty.id,
                    );

                    setState(() {
                      OpenNestStore.landlords.add(landlord);
                    });

                    await OpenNestStore.saveLandlords();

                    if (!mounted || !dialogContext.mounted) return;

                    Navigator.pop(dialogContext);

                    if (accountData['email_sent'] == false) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Landlord account was created, but the invitation email could not be sent.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }

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
                _credentialRow('Property', landlord.propertyName),
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

  void _showLandlordDetails(Landlord landlord) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        child: Text(
                          landlord.fullName.isNotEmpty
                              ? landlord.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              landlord.fullName.isNotEmpty
                                  ? landlord.fullName
                                  : 'Unknown Landlord',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Landlord',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _landlordDetailRow(
                    Icons.badge_outlined,
                    'Landlord ID',
                    landlord.id,
                  ),

                  _landlordDetailRow(
                    Icons.email_outlined,
                    'Email',
                    landlord.email,
                  ),

                  _landlordDetailRow(
                    Icons.phone_outlined,
                    'Phone',
                    landlord.phone,
                  ),

                  _landlordDetailRow(
                    Icons.apartment_outlined,
                    'Property',
                    landlord.propertyName.isNotEmpty
                        ? landlord.propertyName
                        : 'Not assigned',
                  ),

                  _landlordDetailRow(
                    Icons.vpn_key_outlined,
                    'Password Status',
                    landlord.mustResetPassword
                        ? 'Temporary password — reset required'
                        : 'Password set',
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _deleteLandlord(landlord);
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
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

  Widget _landlordDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
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
                const SizedBox(height: 2),
                SelectableText(
                  value.isNotEmpty ? value : 'Not provided',
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

  Future<void> _deleteLandlord(Landlord landlord) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Landlord?'),
          content: Text(
            'Are you sure you want to permanently delete '
            '${landlord.fullName}?\n\n'
            'This will remove the landlord account and their '
            'access to the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting landlord...'),
          duration: Duration(seconds: 2),
        ),
      );

      final response = await OpenNestStore.supabase.functions.invoke(
        'delete-landlord-account',
        body: {'landlord_id': landlord.id, 'email': landlord.email},
      );

      final data = response.data;

      final alreadyDeleted =
          response.status == 404 &&
          data is Map &&
          data['success'] == false &&
          data['error']?.toString().contains(
                "Could not find the landlord's Supabase UUID",
              ) ==
              true;

      if (response.status != 200 && !alreadyDeleted) {
        throw Exception(
          data is Map && data['error'] != null
              ? data['error'].toString()
              : 'Landlord could not be deleted.',
        );
      }

      // Remove the landlord from the local store even when the
      // Supabase account was already deleted manually.
      OpenNestStore.landlords.removeWhere(
        (item) =>
            item.id == landlord.id ||
            item.email.trim().toLowerCase() ==
                landlord.email.trim().toLowerCase(),
      );

      await OpenNestStore.saveLandlords();

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${landlord.fullName} deleted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete landlord: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                      '${landlord.propertyName} • ${landlord.id}',
                    ),
                    isThreeLine: true,
                    onTap: () => _showLandlordDetails(landlord),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteLandlord(landlord);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 10),
                              Text(
                                'Delete Landlord',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
    this.showLogout = false,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final bool showLogout;

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

          if (widget.showLogout) ...[
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
                children: [...previousChildren, ?currentChild],
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
            'landlord_id': user.id,
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

      // When email confirmation is enabled in Supabase, a successful
      // signup normally has no session until the user verifies their email.
      if (authResponse.session == null) {
        if (!mounted) return;

        setState(() {
          _isCreating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created successfully. Please check your email to verify your account.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 6),
          ),
        );

        debugPrint(
          'REGISTRATION: Account created. Waiting for email verification.',
        );

        return;
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

      await OpenNestStore.supabase.from('landlords').upsert({
        'id': user.id,
        'full_name': ownerName,
        'email': email,
        'phone': phone,
      });

      debugPrint('REGISTRATION STEP 2B: Landlord record created');

      // ----------------------------------------------------------
      // 2. Create the property belonging to this owner.
      // ----------------------------------------------------------
      debugPrint('PROPERTY INSERT: START');

      final insertedProperty = await OpenNestStore.supabase
          .from('properties')
          .insert({
            'owner_id': user.id,
            'landlord_id': user.id,
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
  bool _loadingApartments = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });

    _loadApartments();
  }

  Future<void> _loadApartments() async {
    if (mounted) {
      setState(() {
        _loadingApartments = true;
        _loadError = null;
      });
    }

    try {
      await OpenNestStore.loadMarketplaceDataFromSupabase();

      if (!mounted) return;

      setState(() {
        _loadingApartments = false;
      });

      debugPrint(
        'PUBLIC FIND APARTMENT: '
        '${OpenNestStore.properties.length} properties, '
        '${OpenNestStore.apartments.length} units loaded.',
      );
    } catch (e) {
      debugPrint('PUBLIC FIND APARTMENT LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _loadingApartments = false;
        _loadError = 'Could not load apartments.';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Apartment> get _apartments {
    final results = OpenNestStore.apartments.where((apartment) {
      // Only vacant units are publicly available.
      if (apartment.status.toLowerCase() != 'vacant') {
        return false;
      }

      if (_search.isEmpty) return true;

      return apartment.number.toLowerCase().contains(_search) ||
          apartment.type.toLowerCase().contains(_search) ||
          apartment.rent.toLowerCase().contains(_search) ||
          apartment.propertyName.toLowerCase().contains(_search) ||
          apartment.location.toLowerCase().contains(_search);
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
              child: _loadingApartments
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0B3D2E),
                      ),
                    )
                  : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 60,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Could not load apartments',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadApartments,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0B3D2E),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : apartments.isEmpty
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

  Future<void> _forgotPassword() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JUMAAForgotPasswordPage()),
    );
  }

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

    try {
      // ----------------------------------------------------------
      // JUMAA LOGIN — SUPABASE AUTH
      // ----------------------------------------------------------
      final response = await OpenNestStore.supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        throw Exception('Supabase did not return a user.');
      }

      debugPrint('JUMAA LOGIN: Supabase authentication successful.');
      debugPrint('JUMAA LOGIN: user=${user.id}');
      debugPrint('JUMAA LOGIN: email=${user.email}');

      // ----------------------------------------------------------
      // Determine the account role.
      //
      // Owner accounts are created with role = owner.
      // Landlord accounts are created with role = landlord.
      // ----------------------------------------------------------
      String? role = user.userMetadata?['role']
          ?.toString()
          .toLowerCase()
          .trim();

      debugPrint('JUMAA LOGIN: metadata role=$role');

      // ----------------------------------------------------------
      // If Auth metadata does not contain the role, check the
      // profiles table. This makes the login more reliable.
      // ----------------------------------------------------------
      if (role == null || role.isEmpty) {
        try {
          final profile = await OpenNestStore.supabase
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();

          role = profile?['role']?.toString().toLowerCase().trim();

          debugPrint('JUMAA LOGIN: profile role=$role');
        } catch (e) {
          debugPrint('JUMAA LOGIN: Could not read profile role: $e');
        }
      }

      // ----------------------------------------------------------
      // LANDLORD LOGIN
      // ----------------------------------------------------------
      if (role == 'landlord') {
        debugPrint('JUMAA LOGIN: Landlord account detected.');

        final landlord = await OpenNestStore.loadLandlordProfile();

        if (!mounted) return;

        if (landlord == null) {
          await OpenNestStore.supabase.auth.signOut();

          if (!mounted) return;

          throw Exception(
            'This landlord account does not have a valid landlord profile.',
          );
        }

        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool('jumaa_logged_in', true);
        await prefs.setString('jumaa_logged_in_email', email);
        await prefs.setString('jumaa_logged_in_role', 'landlord');

        if (!mounted) return;

        setState(() {
          _isLoggingIn = false;
        });

        // ----------------------------------------------------------
        // FIRST LOGIN — FORCE TEMPORARY PASSWORD CHANGE
        // ----------------------------------------------------------
        if (landlord.mustResetPassword) {
          debugPrint(
            'JUMAA LOGIN: Temporary password detected. '
            'Opening password reset page.',
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LandlordResetPasswordPage(landlord: landlord),
            ),
          );

          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LandlordDashboardPage(
              landlord: landlord,
              isDarkMode: Theme.of(context).brightness == Brightness.dark,
              onDarkModeChanged: (enabled) {
                final state = context
                    .findAncestorStateOfType<_ApartmentAppState>();

                state?._setDarkMode(enabled);
              },
              onLogout: () async {
                await OpenNestStore.supabase.auth.signOut();

                if (!mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const JUMAAWelcomePage()),
                  (route) => false,
                );
              },
            ),
          ),
        );

        return;
      }

      // ----------------------------------------------------------
      // TENANT LOGIN
      // ----------------------------------------------------------
      if (role == 'tenant') {
        debugPrint('JUMAA LOGIN: Tenant account detected.');

        final tenantProfile = await OpenNestStore.loadTenantProfile();

        if (!mounted) return;

        if (tenantProfile == null) {
          await OpenNestStore.supabase.auth.signOut();

          if (!mounted) return;

          throw Exception(
            'This tenant account does not have a valid tenant profile.',
          );
        }

        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool('jumaa_logged_in', true);
        await prefs.setString('jumaa_logged_in_email', email);
        await prefs.setString('jumaa_logged_in_role', 'tenant');

        if (!mounted) return;

        setState(() {
          _isLoggingIn = false;
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TenantDashboardPage(tenantProfile: tenantProfile),
          ),
        );

        return;
      }

      // ----------------------------------------------------------
      // JUMAA OWNER LOGIN
      // ----------------------------------------------------------
      if (role == 'jumaa_owner') {
        debugPrint('JUMAA LOGIN: JUMAA Owner account detected.');

        if (!mounted) return;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('jumaa_logged_in', true);
        await prefs.setString('jumaa_logged_in_email', email);
        await prefs.setString('jumaa_logged_in_role', 'jumaa_owner');

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const JumaaOwnerDashboard()),
        );

        return;
      }

      // ----------------------------------------------------------
      // PROPERTY OWNER LOGIN
      // ----------------------------------------------------------
      if (role == 'owner' || role == null || role.isEmpty) {
        debugPrint('JUMAA LOGIN: Owner account detected.');

        await OpenNestStore.loadOwners();

        if (!mounted) return;

        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool('jumaa_logged_in', true);
        await prefs.setString('jumaa_logged_in_email', email);
        await prefs.setString('jumaa_logged_in_role', 'owner');

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

      // ----------------------------------------------------------
      // UNKNOWN ROLE
      // ----------------------------------------------------------
      await OpenNestStore.supabase.auth.signOut();

      throw Exception(
        'This account is not registered as a JUMAA owner or landlord account.',
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoggingIn = false;
      });

      debugPrint('JUMAA LOGIN ERROR: ${e.message}');

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
        _isLoggingIn = false;
      });

      debugPrint('JUMAA LOGIN ERROR: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
            style: const TextStyle(color: Colors.black, fontSize: 16),
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
            style: const TextStyle(color: Colors.black, fontSize: 16),
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
// JUMAA - SECURE PASSWORD RESET
// ============================================================

class JUMAAPasswordResetService {
  static const String _functionUrl =
      'https://pdezijwjfqyulkkuhoun.supabase.co/functions/v1/reset-jumaa-owner-password';

  static Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      debugPrint(
        'PASSWORD RESET: status=${response.statusCode} body=${response.body}',
      );

      Map<String, dynamic> data;

      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {
          'success': false,
          'error': 'Invalid response from password reset service.',
        };
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }

      return {
        'success': false,
        'error': data['error']?.toString() ?? 'Password reset request failed.',
      };
    } catch (e) {
      debugPrint('PASSWORD RESET ERROR: $e');

      return {
        'success': false,
        'error': 'Unable to connect to the password reset service.',
      };
    }
  }

  static Future<Map<String, dynamic>> requestCode({required String email}) {
    return _call({
      'action': 'request_code',
      'email': email.trim().toLowerCase(),
    });
  }

  static Future<Map<String, dynamic>> verifyCode({
    required String email,
    required String code,
  }) {
    return _call({
      'action': 'verify_code',
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    });
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String resetToken,
    required String newPassword,
  }) {
    return _call({
      'action': 'reset_password',
      'reset_token': resetToken,
      'new_password': newPassword,
    });
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

    setState(() {
      _loading = true;
    });

    final result = await JUMAAPasswordResetService.requestCode(email: email);

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['error']?.toString() ??
                'We could not process your request. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JUMAAVerifyCodePage(email: email)),
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
            'Enter your JUMAA email address and we will send you a verification code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),

          const SizedBox(height: 30),

          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(color: Colors.black, fontSize: 16),
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
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'SEND VERIFICATION CODE',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'If an account exists for this email, a verification code will be sent.',
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
  const JUMAAVerifyCodePage({super.key, required this.email});

  final String email;

  @override
  State<JUMAAVerifyCodePage> createState() => _JUMAAVerifyCodePageState();
}

class _JUMAAVerifyCodePageState extends State<JUMAAVerifyCodePage> {
  final _codeController = TextEditingController();

  bool _verifying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();

    if (!RegExp(r'^\d{5}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the 5-digit verification code.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _verifying = true;
    });

    final result = await JUMAAPasswordResetService.verifyCode(
      email: widget.email,
      code: code,
    );

    if (!mounted) return;

    setState(() {
      _verifying = false;
    });

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['error']?.toString() ?? 'Invalid verification code.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final resetToken = result['reset_token']?.toString();

    if (resetToken == null || resetToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification succeeded, but the reset session could not be created.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => JUMAACreateNewPasswordPage(
          email: widget.email,
          resetToken: resetToken,
        ),
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
            'Enter the 5-digit verification code sent to ${widget.email}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),

          const SizedBox(height: 30),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3EF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.security_rounded,
                  size: 38,
                  color: Color(0xFF0B3D2E),
                ),
                SizedBox(height: 10),
                Text(
                  'A verification code has been sent to your email.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF285548)),
                ),
                SizedBox(height: 6),
                Text(
                  'The code expires in 10 minutes.',
                  textAlign: TextAlign.center,
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
            autocorrect: false,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 5,
            ),
            cursorColor: const Color(0xFF0B3D2E),
            decoration: InputDecoration(
              labelText: 'Verification code',
              prefixIcon: const Icon(Icons.pin_outlined),
              filled: true,
              fillColor: Colors.white,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _verifying ? null : _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B3D2E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: _verifying
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
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
  const JUMAACreateNewPasswordPage({
    super.key,
    required this.email,
    required this.resetToken,
  });

  final String email;
  final String resetToken;

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

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final result = await JUMAAPasswordResetService.resetPassword(
      resetToken: widget.resetToken,
      newPassword: password,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['error']?.toString() ?? 'Could not reset your password.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Password reset successfully. Please log in with your new password.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 900));

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
            style: const TextStyle(color: Colors.black, fontSize: 16),
            cursorColor: const Color(0xFF0B3D2E),
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
            style: const TextStyle(color: Colors.black, fontSize: 16),
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

          const SizedBox(height: 12),

          const Text(
            'Use at least 8 characters. Do not reuse an old password.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 12),
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
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
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
  final Map<String, dynamic>? tenantProfile;
  final String? landlordId;
  final String? landlordName;
  final String? propertyId;
  final String? propertyName;

  const ChatListScreen({
    super.key,
    this.tenantProfile,
    this.landlordId,
    this.landlordName,
    this.propertyId,
    this.propertyName,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _loading = true;
  bool _creatingChat = false;

  final List<Map<String, dynamic>> _contacts = [];
  final List<Map<String, dynamic>> _conversations = [];

  String get _currentUserId =>
      widget.tenantProfile?['auth_user_id']?.toString() ??
      widget.tenantProfile?['user_id']?.toString() ??
      '';

  String get _propertyId =>
      widget.propertyId ??
      widget.tenantProfile?['property_id']?.toString() ??
      '';

  @override
  void initState() {
    super.initState();
    _loadMessagingData();
  }

  Future<void> _loadMessagingData() async {
    if (_propertyId.isEmpty || _currentUserId.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      _contacts.clear();
      _conversations.clear();

      /*
       * Load every tenant belonging to the same property.
       *
       * The current tenant is excluded from the contact list.
       */
      final tenantResponse = await OpenNestStore.supabase
          .from('tenants')
          .select(
            'id, auth_user_id, full_name, email, phone, '
            'property_id, unit_id, account_status',
          )
          .eq('property_id', _propertyId)
          .eq('account_status', 'active');

      for (final row in tenantResponse) {
        final tenant = Map<String, dynamic>.from(row);

        final authId = tenant['auth_user_id']?.toString() ?? '';

        if (authId.isEmpty || authId == _currentUserId) {
          continue;
        }

        _contacts.add({
          'id': authId,
          'profile_id': authId,
          'name': tenant['full_name']?.toString() ?? 'Tenant',
          'email': tenant['email']?.toString() ?? '',
          'type': 'tenant',
          'unit_id': tenant['unit_id']?.toString() ?? '',
          'tenant_id': tenant['id']?.toString() ?? '',
        });
      }

      /*
       * Load the landlord assigned to this property.
       *
       * Relationship:
       * tenant.property_id
       *       -> properties.landlord_id
       *       -> landlords.id
       *       -> landlords.auth_user_id
       *
       * The messaging profile_id MUST be the Supabase Auth UUID.
       */
      debugPrint('MESSAGING: current tenant auth ID = $_currentUserId');
      debugPrint('MESSAGING: current property ID = $_propertyId');

      final propertyResponse = await OpenNestStore.supabase
          .from('properties')
          .select('id, name, landlord_id')
          .eq('id', _propertyId)
          .maybeSingle();

      debugPrint('MESSAGING: property response = $propertyResponse');

      if (propertyResponse != null) {
        final landlordDatabaseId =
            propertyResponse['landlord_id']?.toString() ?? '';

        debugPrint('MESSAGING: property landlord_id = $landlordDatabaseId');

        if (landlordDatabaseId.isNotEmpty) {
          final landlordResponse = await OpenNestStore.supabase
              .from('landlords')
              .select('id, auth_user_id, full_name, email, phone')
              .eq('auth_user_id', landlordDatabaseId)
              .maybeSingle();

          debugPrint('MESSAGING: landlord response = $landlordResponse');

          if (landlordResponse != null) {
            final landlord = Map<String, dynamic>.from(landlordResponse);

            final landlordAuthId = landlord['auth_user_id']?.toString() ?? '';

            debugPrint('MESSAGING: landlord auth_user_id = $landlordAuthId');

            if (landlordAuthId.isNotEmpty && landlordAuthId != _currentUserId) {
              _contacts.insert(0, {
                'id': landlordAuthId,
                'profile_id': landlordAuthId,
                'name': landlord['full_name']?.toString() ?? 'Landlord',
                'email': landlord['email']?.toString() ?? '',
                'type': 'landlord',
                'unit_id': '',
                'tenant_id': '',
              });

              debugPrint(
                'MESSAGING: LANDLORD CONTACT ADDED: '
                '${landlord['full_name']} ($landlordAuthId)',
              );
            } else {
              debugPrint(
                'MESSAGING: landlord auth_user_id is empty '
                'or matches current tenant.',
              );
            }
          } else {
            debugPrint(
              'MESSAGING: NO LANDLORD FOUND for ID '
              '$landlordDatabaseId',
            );
          }
        } else {
          debugPrint('MESSAGING: PROPERTY HAS NO landlord_id');
        }
      } else {
        debugPrint('MESSAGING: PROPERTY NOT FOUND for $_propertyId');
      }

      await _loadExistingConversations();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      debugPrint('TENANT MESSAGES LOAD ERROR: $e');

      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not load messages: $e')));
    }
  }

  Future<void> _loadExistingConversations() async {
    if (_currentUserId.isEmpty || _propertyId.isEmpty) {
      return;
    }

    try {
      final participantRows = await OpenNestStore.supabase
          .from('conversation_participants')
          .select('conversation_id, profile_id, joined_at')
          .eq('profile_id', _currentUserId);

      if (participantRows.isEmpty) {
        return;
      }

      final conversationIds = participantRows
          .map((row) => row['conversation_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      for (final conversationId in conversationIds) {
        final conversation = await OpenNestStore.supabase
            .from('conversations')
            .select('id, property_id, unit_id, created_at')
            .eq('id', conversationId)
            .eq('property_id', _propertyId)
            .maybeSingle();

        if (conversation == null) {
          continue;
        }

        final participants = await OpenNestStore.supabase
            .from('conversation_participants')
            .select('profile_id')
            .eq('conversation_id', conversationId);

        final otherIds = participants
            .map((row) => row['profile_id']?.toString())
            .whereType<String>()
            .where((id) => id != _currentUserId)
            .toList();

        if (otherIds.isEmpty) {
          continue;
        }

        final otherId = otherIds.first;

        final contact = _contacts.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['id']?.toString() == otherId,
          orElse: () => null,
        );

        /*
         * Only display conversations with permitted contacts.
         * This automatically prevents tenant access to JUMAA owner/admin
         * accounts because they are never added to _contacts.
         */
        if (contact == null) {
          continue;
        }

        final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 7));

        final latestMessage = await OpenNestStore.supabase
            .from('messages')
            .select('id, sender_id, receiver_id, message, status, created_at')
            .eq('conversation_id', conversationId)
            .gte('created_at', cutoff.toIso8601String())
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        _conversations.add({
          'conversation_id': conversationId,
          'contact': contact,
          'latest_message': latestMessage,
          'created_at': conversation['created_at'],
        });
      }

      _conversations.sort((a, b) {
        final aMessage = a['latest_message'];
        final bMessage = b['latest_message'];

        final aDate =
            DateTime.tryParse(aMessage?['created_at']?.toString() ?? '') ??
            DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime(1970);

        final bDate =
            DateTime.tryParse(bMessage?['created_at']?.toString() ?? '') ??
            DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime(1970);

        return bDate.compareTo(aDate);
      });
    } catch (e) {
      debugPrint('TENANT CONVERSATIONS LOAD ERROR: $e');
    }
  }

  Future<String?> _getOrCreateConversation(Map<String, dynamic> contact) async {
    final receiverId = contact['id']?.toString() ?? '';

    if (_currentUserId.isEmpty || receiverId.isEmpty || _propertyId.isEmpty) {
      return null;
    }

    debugPrint('===== CHAT RPC =====');
    debugPrint('Current user: $_currentUserId');
    debugPrint('Property: $_propertyId');
    debugPrint('Receiver: $receiverId');
    debugPrint('===================');

    final response = await OpenNestStore.supabase.rpc(
      'get_or_create_apartment_conversation',
      params: {'p_property_id': _propertyId, 'p_receiver_id': receiverId},
    );

    final conversationId = response?.toString();

    if (conversationId == null || conversationId.isEmpty) {
      return null;
    }

    debugPrint('CHAT: conversation ready = $conversationId');

    return conversationId;
  }

  Future<void> _openContact(Map<String, dynamic> contact) async {
    if (_creatingChat) return;

    setState(() {
      _creatingChat = true;
    });

    try {
      final conversationId = await _getOrCreateConversation(contact);

      if (!mounted) return;

      if (conversationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create this conversation.')),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TenantChatConversationScreen(
            conversationId: conversationId,
            currentUserId: _currentUserId,
            contact: contact,
            propertyId: _propertyId,
          ),
        ),
      );

      await _loadMessagingData();
    } catch (e) {
      debugPrint('TENANT OPEN CHAT ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _creatingChat = false;
        });
      }
    }
  }

  Widget _contactAvatar(Map<String, dynamic> contact, {double radius = 25}) {
    final isLandlord = contact['type'] == 'landlord';

    return CircleAvatar(
      radius: radius,
      backgroundColor: isLandlord
          ? const Color(0xFF075E54)
          : const Color(0xFF128C7E),
      child: Icon(
        isLandlord ? Icons.home_work_outlined : Icons.person_outline,
        color: Colors.white,
        size: radius,
      ),
    );
  }

  String _formatTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return '';

    final local = date.toLocal();

    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessagingData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMessagingData,
              child: _contacts.isEmpty
                  ? _buildEmptyMessages()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(18, 20, 18, 10),
                          child: Text(
                            'Apartment members',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        ..._contacts.map((contact) {
                          final conversation = _conversations
                              .cast<Map<String, dynamic>?>()
                              .firstWhere(
                                (item) =>
                                    item?['contact']?['id']?.toString() ==
                                    contact['id']?.toString(),
                                orElse: () => null,
                              );

                          final latestMessage = conversation?['latest_message'];

                          final hasMessage = latestMessage != null;

                          final subtitle = hasMessage
                              ? latestMessage['message']?.toString() ??
                                    'Message'
                              : 'Tap to start chatting';

                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 7,
                                ),
                                leading: _contactAvatar(contact, radius: 28),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        contact['name']?.toString() ?? 'Member',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (hasMessage)
                                      Text(
                                        _formatTime(
                                          latestMessage['created_at'],
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: hasMessage
                                                ? Colors.grey.shade700
                                                : Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: contact['type'] == 'landlord'
                                              ? const Color(0xFF075E54)
                                                    .withValues(alpha: 0.10)
                                              : const Color(0xFF128C7E)
                                                    .withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          contact['type'] == 'landlord'
                                              ? 'Landlord'
                                              : 'Tenant',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: contact['type'] == 'landlord'
                                                ? const Color(0xFF075E54)
                                                : const Color(0xFF128C7E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                                onTap: () => _openContact(contact),
                              ),
                              const Divider(height: 1, indent: 82),
                            ],
                          );
                        }),
                      ],
                    ),
            ),
    );
  }

  Widget _buildEmptyMessages() {
    return RefreshIndicator(
      onRefresh: _loadMessagingData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 80),
          CircleAvatar(
            radius: 45,
            backgroundColor: const Color(0xFF075E54).withValues(alpha: 0.10),
            child: const Icon(
              Icons.people_outline,
              size: 48,
              color: Color(0xFF075E54),
            ),
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text(
              'No apartment members yet',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Your landlord and other tenants will appear here when they are available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class TenantChatConversationScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final Map<String, dynamic> contact;
  final String propertyId;

  const TenantChatConversationScreen({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.contact,
    required this.propertyId,
  });

  @override
  State<TenantChatConversationScreen> createState() =>
      _TenantChatConversationScreenState();
}

class _TenantChatConversationScreenState
    extends State<TenantChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  String get _receiverId => widget.contact['id']?.toString() ?? '';

  String get _contactName => widget.contact['name']?.toString() ?? 'Member';

  bool get _isLandlord => widget.contact['type'] == 'landlord';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 7));

      final response = await OpenNestStore.supabase
          .from('messages')
          .select(
            'id, sender_id, receiver_id, conversation_id, '
            'message, status, created_at, delivered_at, read_at',
          )
          .eq('conversation_id', widget.conversationId)
          .gte('created_at', cutoff.toIso8601String())
          .order('created_at', ascending: true);

      if (!mounted) return;

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('TENANT CHAT LOAD ERROR: $e');

      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not load messages: $e')));
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _sending || _receiverId.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await OpenNestStore.supabase.from('messages').insert({
        'sender_id': widget.currentUserId,
        'receiver_id': _receiverId,
        'conversation_id': widget.conversationId,
        'message': text,
        'status': 'sent',
      });

      _messageController.clear();

      await _loadMessages();
    } catch (e) {
      debugPrint('TENANT CHAT SEND ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not send message: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return '';

    final local = date.toLocal();

    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildBubble(Map<String, dynamic> message) {
    final sender = message['sender_id']?.toString() ?? '';

    final isMine = sender == widget.currentUserId;

    final text = message['message']?.toString() ?? '';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        margin: const EdgeInsets.only(left: 8, right: 8, bottom: 5),
        padding: const EdgeInsets.fromLTRB(10, 7, 8, 6),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFD9FDD3) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: Radius.circular(isMine ? 10 : 2),
            bottomRight: Radius.circular(isMine ? 2 : 10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, height: 1.3),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              _formatTime(message['created_at']),
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
            if (isMine) ...[
              const SizedBox(width: 3),
              Icon(
                message['status'] == 'read' ? Icons.done_all : Icons.done,
                size: 13,
                color: message['status'] == 'read'
                    ? const Color(0xFF53BDEB)
                    : Colors.grey,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
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
                  vertical: 11,
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
                  borderSide: const BorderSide(color: Color(0xFF075E54)),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 7),
          Material(
            color: const Color(0xFF075E54),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _sending ? null : _sendMessage,
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: _sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 21),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE7DE),
      appBar: AppBar(
        toolbarHeight: 58,
        elevation: 0,
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF128C7E),
              child: Icon(
                _isLandlord ? Icons.home_work_outlined : Icons.person_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _contactName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isLandlord ? 'Landlord' : 'Tenant',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadMessages,
                      child: _messages.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 230),
                                Center(
                                  child: Text(
                                    'No messages yet',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                return _buildBubble(_messages[index]);
                              },
                            ),
                    ),
            ),
            _buildInput(),
          ],
        ),
      ),
    );
  }
}
