class Landlord {
  String id;
  String fullName;
  String email;
  String phone;
  String temporaryPassword;
  bool mustResetPassword;
  String apartmentName;
  String apartmentId;

  Landlord({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.temporaryPassword,
    required this.mustResetPassword,
    required this.apartmentName,
    this.apartmentId = '',
  });
}
