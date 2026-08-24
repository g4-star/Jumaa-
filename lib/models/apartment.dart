class Apartment {
  String id;
  String number;
  String type;
  String rent;
  String tenant;
  String status;

  String propertyId;
  String propertyName;

  String location;
  String description;
  List<String> imagePaths;
  List<String> videoPaths;

  bool isBoosted;
  DateTime? boostExpiresAt;

  Apartment({
    this.id = '',
    required this.number,
    required this.type,
    required this.rent,
    this.tenant = '',
    required this.status,
    this.propertyId = '',
    this.propertyName = '',
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
