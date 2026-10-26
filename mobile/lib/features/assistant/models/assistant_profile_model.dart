class AssistantProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final List<AssignedStoreInfo> assignedStores;

  AssistantProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.role,
    required this.assignedStores,
  });

  factory AssistantProfileModel.fromMap(
    Map<String, dynamic> map,
    List<AssignedStoreInfo> stores,
  ) {
    return AssistantProfileModel(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      avatarUrl: map['avatar_url'],
      role: map['role'] ?? 'assistant',
      assignedStores: stores,
    );
  }
}

class AssignedStoreInfo {
  final String storeId;
  final String storeName;
  final String? storeLogoUrl;
  final String? storeCity;
  final DateTime assignedAt;

  AssignedStoreInfo({
    required this.storeId,
    required this.storeName,
    this.storeLogoUrl,
    this.storeCity,
    required this.assignedAt,
  });

  factory AssignedStoreInfo.fromMap(Map<String, dynamic> map) {
    final store = map['stores'] as Map<String, dynamic>? ?? {};
    return AssignedStoreInfo(
      storeId: map['store_id'] ?? store['id'] ?? '',
      storeName: store['name'] ?? 'Toko UMK',
      storeLogoUrl: store['logo_url'],
      storeCity: store['address'],
      assignedAt: map['assigned_at'] != null
          ? DateTime.parse(map['assigned_at'])
          : DateTime.now(),
    );
  }
}
