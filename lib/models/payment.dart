class Payment {
  String id;
  String tenantId;
  String propertyId;
  String unitId;

  double amount;
  String paymentType;
  String paymentStatus;

  DateTime dueDate;
  DateTime? paidAt;

  String paymentReference;
  DateTime createdAt;

  Payment({
    this.id = '',
    required this.tenantId,
    required this.propertyId,
    required this.unitId,
    required this.amount,
    this.paymentType = 'rent',
    this.paymentStatus = 'pending',
    required this.dueDate,
    this.paidAt,
    this.paymentReference = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPaid => paymentStatus == 'paid';

  bool get isPending => paymentStatus == 'pending';

  bool get isProcessing => paymentStatus == 'processing';

  bool get isFailed => paymentStatus == 'failed';

  bool get isCancelled => paymentStatus == 'cancelled';

  bool get isOverdue {
    if (isPaid || isCancelled) {
      return false;
    }

    final today = DateTime.now();

    final todayOnly = DateTime(today.year, today.month, today.day);

    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);

    return dueDateOnly.isBefore(todayOnly);
  }

  String get displayStatus {
    if (isPaid) {
      return 'Paid';
    }

    if (isOverdue) {
      return 'Overdue';
    }

    if (isProcessing) {
      return 'Processing';
    }

    if (isFailed) {
      return 'Failed';
    }

    if (isCancelled) {
      return 'Cancelled';
    }

    return 'Pending';
  }
}
