import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/landlord.dart';

class LandlordSettingsPage extends StatefulWidget {
  final Landlord landlord;
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onLogout;

  const LandlordSettingsPage({
    super.key,
    required this.landlord,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    required this.onLogout,
  });

  @override
  State<LandlordSettingsPage> createState() => _LandlordSettingsPageState();
}

class _LandlordSettingsPageState extends State<LandlordSettingsPage> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  String? _profileImagePath;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.landlord.fullName);

    _phoneController = TextEditingController(text: widget.landlord.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() {
      _profileImagePath = image.path;
    });
  }

  void _editProfile() {
    _nameController.text = widget.landlord.fullName;
    _phoneController.text = widget.landlord.phone;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: _profileImagePath != null
                            ? FileImage(File(_profileImagePath!))
                            : null,
                        child: _profileImagePath == null
                            ? const Icon(Icons.person, size: 48)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          onPressed: _pickProfileImage,
                          icon: const Icon(Icons.camera_alt, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),

                const SizedBox(height: 22),

                FilledButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    final phone = _phoneController.text.trim();

                    if (name.isEmpty || phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Name and phone number are required.'),
                        ),
                      );
                      return;
                    }

                    widget.landlord.fullName = name;
                    widget.landlord.phone = phone;

                    setState(() {});

                    Navigator.pop(sheetContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully.'),
                      ),
                    );
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ),
        );
      },
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

    try {
      await Supabase.instance.client.auth.signOut();

      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('jumaa_logged_in');
      await prefs.remove('jumaa_logged_in_email');
      await prefs.remove('jumaa_logged_in_role');

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to log out: $e')));
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'JUMAA',
      applicationVersion: '1.0.0',
      applicationLegalese: '© JUMAA',
      children: const [
        SizedBox(height: 16),
        Text(
          'JUMAA helps apartment owners, landlords and tenants manage properties, bookings, communication and payments in one place.',
        ),
      ],
    );
  }

  void _showSupport() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Support'),
          content: const Text(
            'Need help with JUMAA? Contact the apartment administrator or JUMAA support.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

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
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: _profileImagePath != null
                    ? FileImage(File(_profileImagePath!))
                    : null,
                child: _profileImagePath == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(
                widget.landlord.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(widget.landlord.email),
              trailing: const Icon(Icons.chevron_right),
              onTap: _editProfile,
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'Appearance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Card(
            child: SwitchListTile(
              value: widget.isDarkMode,
              onChanged: widget.onDarkModeChanged,
              title: const Text('Dark mode'),
              subtitle: const Text('Use dark appearance throughout the app.'),
              secondary: Icon(
                widget.isDarkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
              ),
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Edit Profile'),
                  subtitle: const Text(
                    'Change your display name, phone and image.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editProfile,
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'Information & Help',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showAbout,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('Support'),
                  subtitle: const Text('Get help with JUMAA.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showSupport,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Sign out of your JUMAA account.'),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: _logout,
            ),
          ),

          const SizedBox(height: 24),

          Card(
            child: ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Sign out of your landlord account.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onLogout,
            ),
          ),

          const SizedBox(height: 30),

          Center(
            child: Text(
              'JUMAA • Version 1.0.0',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
