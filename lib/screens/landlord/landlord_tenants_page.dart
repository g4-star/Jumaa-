import 'package:flutter/material.dart';

import '../../models/landlord.dart';

class LandlordTenantsPage extends StatefulWidget {
  final Landlord landlord;

  const LandlordTenantsPage({
    super.key,
    required this.landlord,
  });

  @override
  State<LandlordTenantsPage> createState() =>
      _LandlordTenantsPageState();
}

class _LandlordTenantsPageState
    extends State<LandlordTenantsPage> {
  final List<Map<String, String>> _tenants = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tenants',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _tenants.isEmpty
          ? _emptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: _tenants.length,
              itemBuilder: (context, index) {
                final tenant = _tenants[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        tenant['name']!
                            .substring(0, 1)
                            .toUpperCase(),
                      ),
                    ),
                    title: Text(
                      tenant['name']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Unit ${tenant['unit']}',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: () => _editTenant(
                      context,
                      index,
                    ),
                  ),
                );
              },
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
              Icons.people_outline,
              size: 65,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 15),
            const Text(
              'No tenants yet',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Approved bookings will automatically appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editTenant(
    BuildContext context,
    int index,
  ) {
    final tenant = _tenants[index];

    final nameController =
        TextEditingController(text: tenant['name']);

    final unitController =
        TextEditingController(text: tenant['unit']);

    final phoneController =
        TextEditingController(text: tenant['phone']);

    final emailController =
        TextEditingController(text: tenant['email']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(sheetContext)
                    .viewInsets
                    .bottom +
                18,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Edit Tenant',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit number',
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                  ),
                ),

                const SizedBox(height: 20),

                FilledButton(
                  onPressed: () {
                    setState(() {
                      tenant['name'] =
                          nameController.text.trim();
                      tenant['unit'] =
                          unitController.text.trim();
                      tenant['phone'] =
                          phoneController.text.trim();
                      tenant['email'] =
                          emailController.text.trim();
                    });

                    Navigator.pop(sheetContext);

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Tenant changes saved.',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Save Changes',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
