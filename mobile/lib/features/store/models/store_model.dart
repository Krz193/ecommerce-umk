class StoreModel {
  final String id;

  final String ownerId;

  final String name;

  final String slug;

  final String? description;

  final String? phone;

  final String? address;

  final String status;

  StoreModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slug,
    required this.description,
    required this.phone,
    required this.address,
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
      status: map['status'],
    );
  }
}
