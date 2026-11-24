class StoreModel {
  final String id;

  final String ownerId;

  final String name;

  final String slug;

  final String? description;

  final String? phone;

  final String? address;

  final String? province;

  final String? city;

  final String? district;

  final String? postalCode;

  final String? notes;

  final String? biteshipAreaId;

  final double? latitude;

  final double? longitude;

  final String status;

  StoreModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slug,
    required this.description,
    required this.phone,
    required this.address,
    this.province,
    this.city,
    this.district,
    this.postalCode,
    this.notes,
    this.biteshipAreaId,
    this.latitude,
    this.longitude,
    required this.status,
  });

  factory StoreModel.fromMap(Map<String, dynamic> map) {
    return StoreModel(
      id: map['id'],
      ownerId: map['owner_id'],
      name: map['name'],
      slug: map['slug'],
      description: map['description'],
      phone: map['phone'],
      address: map['address'],
      province: map['province'],
      city: map['city'],
      district: map['district'],
      postalCode: map['postal_code'],
      notes: map['notes'],
      biteshipAreaId: map['biteship_area_id'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      status: map['status'],
    );
  }
}
