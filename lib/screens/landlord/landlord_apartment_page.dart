import 'package:flutter/material.dart';

import '../../models/apartment.dart';
import '../../models/landlord.dart';
import '../../main.dart' show OpenNestStore;

class LandlordApartmentPage extends StatefulWidget {
  final Landlord landlord;

  const LandlordApartmentPage({
    super.key,
    required this.landlord,
  });

  @override
  State<LandlordApartmentPage> createState() =>
      _LandlordApartmentPageState();
}

class _LandlordApartmentPageState
    extends State<LandlordApartmentPage> {
  bool _editingDescription = false;
  bool _saving = false;

  late TextEditingController _descriptionController;

  List<Apartment> get units {
    if (widget.landlord.propertyId.isNotEmpty) {
      final byId = OpenNestStore.apartments
          .where(
            (unit) =>
                unit.propertyId == widget.landlord.propertyId,
          )
          .toList();

      if (byId.isNotEmpty) {
        return byId;
      }
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

  int get occupied =>
      units.where((unit) => unit.status == 'Occupied').length;

  int get vacant =>
      units.where((unit) => unit.status == 'Vacant').length;

  int get maintenance =>
      units.where(
        (unit) => unit.status == 'Under Maintenance',
      ).length;

  String get currentDescription {
    if (units.isEmpty) return '';

    final description = units.first.description.trim();

    return description.isEmpty
        ? 'No apartment description has been added yet.'
        : description;
  }

  @override
  void initState() {
    super.initState();

    _descriptionController = TextEditingController(
      text: currentDescription,
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveDescription() async {
    if (units.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final description = _descriptionController.text.trim();

    for (final unit in units) {
      unit.description = description;
    }

    final propertyId = widget.landlord.propertyId.isNotEmpty
        ? widget.landlord.propertyId
        : units.first.propertyId;

    await OpenNestStore.savePropertyDescription(
      propertyId: propertyId,
      description: description,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
      _editingDescription = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Apartment description updated.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apartmentName = widget.landlord.propertyName.isNotEmpty
        ? widget.landlord.propertyName
        : (units.isNotEmpty ? units.first.propertyName : 'My Apartment');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Apartment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await OpenNestStore.loadPropertiesFromSupabase();
          await OpenNestStore.loadUnitsFromSupabase();

          if (mounted) {
            setState(() {});
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              apartmentName,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              widget.landlord.propertyId.isNotEmpty
                  ? 'Assigned apartment'
                  : 'Apartment',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Unit Overview',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Occupied',
                    occupied,
                    Icons.people_outline,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    'Vacant',
                    vacant,
                    Icons.home_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    'Maintenance',
                    maintenance,
                    Icons.build_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Apartment Description',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _editingDescription =
                          !_editingDescription;

                      if (_editingDescription) {
                        _descriptionController.text =
                            currentDescription;
                      }
                    });
                  },
                  icon: Icon(
                    _editingDescription
                        ? Icons.close
                        : Icons.edit_outlined,
                  ),
                  label: Text(
                    _editingDescription ? 'Cancel' : 'Edit',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (_editingDescription)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _descriptionController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      hintText:
                          'Describe the apartment...',
                    ),
                  ),

                  const SizedBox(height: 12),

                  FilledButton.icon(
                    onPressed:
                        _saving ? null : _saveDescription,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Saving...' : 'Save Changes',
                    ),
                  ),
                ],
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    currentDescription,
                    style: const TextStyle(
                      height: 1.5,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 28),

            const Text(
              'Units',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (units.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    children: [
                      Icon(
                        Icons.apartment_outlined,
                        size: 50,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No units found',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...units.map(_unitCard),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    String title,
    int value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 6,
        ),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 7),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitCard(Apartment unit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            unit.status == 'Occupied'
                ? Icons.person_outline
                : Icons.home_outlined,
          ),
        ),
        title: Text(
          'Unit ${unit.number}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${unit.type} • ${unit.rent}',
        ),
        trailing: Chip(
          label: Text(
            unit.status,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }
}
