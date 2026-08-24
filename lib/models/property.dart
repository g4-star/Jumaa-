class Property {
  String id;
  String ownerId;
  String name;

  // Public location information
  String county;
  String subcounty;
  String location;
  String address;

  // Map coordinates
  double? latitude;
  double? longitude;

  String description;
  String email;
  String phone;

  // Payment information
  String paymentMethod;
  String mpesaTillNumber;
  String mpesaPaybillNumber;
  String mpesaAccountNumber;
  bool paymentsEnabled;

  // Property media
  List<String> imagePaths;
  List<String> videoPaths;

  Property({
    required this.id,
    required this.ownerId,
    required this.name,
    this.county = '',
    this.subcounty = '',
    this.location = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.description = '',
    this.email = '',
    this.phone = '',
    this.paymentMethod = 'till',
    this.mpesaTillNumber = '',
    this.mpesaPaybillNumber = '',
    this.mpesaAccountNumber = '',
    this.paymentsEnabled = true,
    this.imagePaths = const [],
    this.videoPaths = const [],
  });
}
