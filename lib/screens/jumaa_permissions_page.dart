import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

import '../services/jumaa_permission_service.dart';

class JumaaPermissionsPage extends StatefulWidget {
  final VoidCallback? onFinished;
  final WidgetBuilder? destinationBuilder;

  const JumaaPermissionsPage({
    super.key,
    this.onFinished,
    this.destinationBuilder,
  });

  @override
  State<JumaaPermissionsPage> createState() => _JumaaPermissionsPageState();
}

class _JumaaPermissionsPageState extends State<JumaaPermissionsPage> {
  final _permissionService = JumaaPermissionService.instance;

  bool _notificationGranted = false;
  bool _locationGranted = false;

  bool _notificationLoading = false;
  bool _locationLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notificationSettings =
        await FirebaseMessaging.instance.getNotificationSettings();

    final locationReady = await _permissionService.canUseLocation();

    if (!mounted) return;

    setState(() {
      _notificationGranted =
          notificationSettings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          notificationSettings.authorizationStatus ==
              AuthorizationStatus.provisional;

      _locationGranted = locationReady;
    });
  }

  Future<void> _requestNotifications() async {
    if (_notificationLoading) return;

    setState(() {
      _notificationLoading = true;
    });

    await _permissionService.requestNotifications();

    await _checkPermissions();

    if (!mounted) return;

    setState(() {
      _notificationLoading = false;
    });
  }

  Future<void> _requestLocation() async {
    if (_locationLoading) return;

    setState(() {
      _locationLoading = true;
    });

    final permission = await _permissionService.requestLocation();

    if (!mounted) return;

    if (permission == LocationPermission.deniedForever) {
      await _showLocationSettingsDialog();
    }

    await _checkPermissions();

    if (!mounted) return;

    setState(() {
      _locationLoading = false;
    });
  }

  Future<void> _showLocationSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Location permission needed'),
          content: const Text(
            'Location access is currently blocked for JUMAA. '
            'You can enable it from your phone settings to use '
            'nearby apartments and distance features.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _permissionService.openSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Widget _permissionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool granted,
    required bool loading,
    required VoidCallback onAllow,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: granted
              ? Colors.green.withValues(alpha: 0.35)
              : Colors.grey.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 27,
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
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (granted)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 22,
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 42,
                  child: FilledButton(
                    onPressed: granted || loading ? null : onAllow,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                            ),
                          )
                        : Text(granted ? 'Allowed' : 'Allow'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'JUMAA Permissions',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Make JUMAA work better for you',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Choose the permissions you want to give JUMAA. '
                      'You can change them anytime from your phone settings.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              const Text(
                'Recommended permissions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'These permissions help JUMAA provide its main features.',
                style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.65),
                ),
              ),

              const SizedBox(height: 18),

              _permissionCard(
                icon: Icons.notifications_active_rounded,
                iconColor: Colors.orange,
                title: 'Notifications',
                description:
                    'Receive booking updates, messages, viewing requests, '
                    'rent reminders and important JUMAA announcements.',
                granted: _notificationGranted,
                loading: _notificationLoading,
                onAllow: _requestNotifications,
              ),

              _permissionCard(
                icon: Icons.location_on_rounded,
                iconColor: Colors.blue,
                title: 'Location',
                description:
                    'Find apartments near you, calculate your distance '
                    'from properties and get better directions.',
                granted: _locationGranted,
                loading: _locationLoading,
                onAllow: _requestLocation,
              ),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Camera access is requested only when you choose '
                        'to take a photo. JUMAA does not need camera access '
                        'just to browse apartments.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('jumaa_permissions_seen', true);

                    if (!context.mounted) return;

                    final destinationBuilder = widget.destinationBuilder;
                    final onFinished = widget.onFinished;

                    if (destinationBuilder != null) {
                      final destination = destinationBuilder(context);

                      if (!context.mounted) return;

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => destination,
                        ),
                      );

                      return;
                    }

                    onFinished?.call();
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue to JUMAA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
