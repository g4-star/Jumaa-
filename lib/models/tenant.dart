class Tenant {
  String id;
  String authUserId;
  String bookingRequestId;
  String propertyId;
  String unitId;
  String name;
  String email;
  String phone;
  String apartment;
  String rent;
  String paymentStatus;
  String accountStatus;
  DateTime? moveInDate;

  Tenant({
    this.id = '',
    this.authUserId = '',
    this.bookingRequestId = '',
    this.propertyId = '',
    this.unitId = '',
    required this.name,
    required this.email,
    required this.phone,
    required this.apartment,
    required this.rent,
    required this.paymentStatus,
    this.accountStatus = 'active',
    this.moveInDate,
  });
}
