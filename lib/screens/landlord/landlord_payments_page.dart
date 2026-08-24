import 'package:flutter/material.dart';

import '../../models/landlord.dart';
import '../../models/payment.dart';

class LandlordPaymentsPage extends StatefulWidget {
  final Landlord landlord;

  const LandlordPaymentsPage({
    super.key,
    required this.landlord,
  });

  @override
  State<LandlordPaymentsPage> createState() =>
      _LandlordPaymentsPageState();
}

class _LandlordPaymentsPageState
    extends State<LandlordPaymentsPage> {
  String _filter = 'All';

  final List<Payment> _payments = [];

  List<Payment> get filteredPayments {
    if (_filter == 'All') {
      return _payments;
    }

    return _payments.where((payment) {
      return payment.displayStatus.toLowerCase() ==
          _filter.toLowerCase();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payments',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            widget.landlord.apartmentName.isNotEmpty
                ? widget.landlord.apartmentName
                : 'Apartment Payments',
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'View and track tenant payments.',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 22),

          _summary(),

          const SizedBox(height: 24),

          const Text(
            'Payment History',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All'),
                _filterChip('Paid'),
                _filterChip('Pending'),
                _filterChip('Overdue'),
              ],
            ),
          ),

          const SizedBox(height: 15),

          if (filteredPayments.isEmpty)
            _emptyState()
          else
            ...filteredPayments.map(_paymentCard),
        ],
      ),
    );
  }

  Widget _summary() {
    final paid = _payments.where(
      (payment) =>
          payment.displayStatus.toLowerCase() == 'paid',
    ).length;

    final pending = _payments.where(
      (payment) =>
          payment.displayStatus.toLowerCase() == 'pending',
    ).length;

    final overdue = _payments.where(
      (payment) =>
          payment.displayStatus.toLowerCase() == 'overdue',
    ).length;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            'Paid',
            paid.toString(),
            Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            'Pending',
            pending.toString(),
            Icons.pending_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            'Overdue',
            overdue.toString(),
            Icons.warning_amber_outlined,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    String value,
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
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
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

  Widget _filterChip(String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(value),
        selected: _filter == value,
        onSelected: (_) {
          setState(() {
            _filter = value;
          });
        },
      ),
    );
  }

  Widget _paymentCard(Payment payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            payment.displayStatus.toLowerCase() == 'paid'
                ? Icons.check
                : Icons.payments_outlined,
          ),
        ),
        title: Text(
          payment.tenantId,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'KES ${payment.amount.toStringAsFixed(2)} • Unit ${payment.unitId} • Due ${_formatDate(payment.dueDate)}',
        ),
        trailing: Chip(
          label: Text(
            payment.displayStatus,
            style: const TextStyle(
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.payments_outlined,
              size: 55,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Text(
              'No payments yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tenant payment records will appear here.',
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
}
