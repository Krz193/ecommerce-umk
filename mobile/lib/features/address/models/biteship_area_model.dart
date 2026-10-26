class BiteshipAreaModel {
  final String id;
  final String name;
  final String province;
  final String city;
  final String district;
  final String? subdistrict;
  final String postalCode;

  const BiteshipAreaModel({
    required this.id,
    required this.name,
    required this.province,
    required this.city,
    required this.district,
    this.subdistrict,
    required this.postalCode,
  });

  factory BiteshipAreaModel.fromMap(Map<String, dynamic> map) {
    return BiteshipAreaModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      province: map['province']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      subdistrict: map['subdistrict']?.toString(),
      postalCode: map['postal_code']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'province': province,
      'city': city,
      'district': district,
      'subdistrict': subdistrict,
      'postal_code': postalCode,
    };
  }
}
