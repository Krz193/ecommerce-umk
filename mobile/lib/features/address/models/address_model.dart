class AddressModel {
  final String id;
  final String recipientName;
  final String phoneNumber;
  final String fullAddress;
  final bool isDefault;

  AddressModel({
    required this.id,
    required this.recipientName,
    required this.phoneNumber,
    required this.fullAddress,
    required this.isDefault,
  });

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'],
      recipientName: map['recipient_name'],
      phoneNumber: map['recipient_phone'],
      fullAddress: map['full_address'],
      isDefault: map['is_default'] ?? false,
    );
  }
}
