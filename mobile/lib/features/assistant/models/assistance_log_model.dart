class AssistanceLogModel {
  final String id;
  final String assistantId;
  final String storeId;
  final String actionType;
  final String title;
  final String? description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String? storeName;

  AssistanceLogModel({
    required this.id,
    required this.assistantId,
    required this.storeId,
    required this.actionType,
    required this.title,
    this.description,
    required this.metadata,
    required this.createdAt,
    this.storeName,
  });

  factory AssistanceLogModel.fromMap(Map<String, dynamic> map) {
    final store = map['stores'] as Map<String, dynamic>?;
    return AssistanceLogModel(
      id: map['id'] ?? '',
      assistantId: map['assistant_id'] ?? '',
      storeId: map['store_id'] ?? '',
      actionType: map['action_type'] ?? 'other',
      title: map['title'] ?? '',
      description: map['description'],
      metadata: (map['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      storeName: store?['name'],
    );
  }

  String get actionTypeLabel {
    switch (actionType) {
      case 'create_product':
        return 'Tambah Produk';
      case 'update_product':
        return 'Edit Produk';
      case 'update_stock':
        return 'Stok Opname';
      case 'ship_order':
        return 'Kirim Pesanan';
      case 'create_content':
        return 'Buat Konten';
      case 'update_content':
        return 'Edit Konten';
      case 'update_profile':
        return 'Update Profil';
      default:
        return 'Aktivitas Pendampingan';
    }
  }
}
