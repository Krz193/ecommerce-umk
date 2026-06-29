class AddressModel {
  final String id;
  final String? label;
  final String recipientName;
  final String phoneNumber;
  final String province;
  final String city;
  final String? district;
  final String? postalCode;
  final String fullAddress;
  final bool isDefault;

  AddressModel({
    required this.id,
    this.label,
    required this.recipientName,
    required this.phoneNumber,
    required this.province,
    required this.city,
    this.district,
    this.postalCode,
    required this.fullAddress,
    required this.isDefault,
  });

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'],
      label: map['label'],
      recipientName: map['recipient_name'],
      phoneNumber: map['recipient_phone'],
      province: map['province'],
      city: map['city'],
      district: map['district'],
      postalCode: map['postal_code'],
      fullAddress: map['full_address'],
      isDefault: map['is_default'] ?? false,
    );
  }
}
