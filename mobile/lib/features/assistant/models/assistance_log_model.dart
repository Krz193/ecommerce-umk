class AssistanceLogModel {
  final String id;
  final String assistantId;
  final String storeId;
  final String actionType;
  final String title;
  final String? description;
  final String? channel;
  final int reachCount;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int inquiriesCount;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String? storeName;

  int get totalInteractions =>
      likesCount + commentsCount + sharesCount + inquiriesCount;

  bool get hasEngagementMetrics =>
      actionType == 'engagement' ||
      reachCount > 0 ||
      totalInteractions > 0 ||
      (channel != null && channel!.isNotEmpty);

  AssistanceLogModel({
    required this.id,
    required this.assistantId,
    required this.storeId,
    required this.actionType,
    required this.title,
    this.description,
    this.channel,
    this.reachCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.inquiriesCount = 0,
    required this.metadata,
    required this.createdAt,
    this.storeName,
  });

  factory AssistanceLogModel.fromMap(Map<String, dynamic> map) {
    final store = map['stores'] as Map<String, dynamic>?;
    final meta = (map['metadata'] as Map<String, dynamic>?) ?? {};
    return AssistanceLogModel(
      id: map['id'] ?? '',
      assistantId: map['assistant_id'] ?? '',
      storeId: map['store_id'] ?? '',
      actionType: map['action_type'] ?? 'other',
      title: map['title'] ?? '',
      description: map['description'],
      channel: map['channel'] as String? ?? meta['channel'] as String?,
      reachCount:
          (map['reach_count'] as num?)?.toInt() ??
          (meta['reach_count'] as num?)?.toInt() ??
          0,
      likesCount:
          (map['likes_count'] as num?)?.toInt() ??
          (meta['likes_count'] as num?)?.toInt() ??
          0,
      commentsCount:
          (map['comments_count'] as num?)?.toInt() ??
          (meta['comments_count'] as num?)?.toInt() ??
          0,
      sharesCount:
          (map['shares_count'] as num?)?.toInt() ??
          (meta['shares_count'] as num?)?.toInt() ??
          0,
      inquiriesCount:
          (map['inquiries_count'] as num?)?.toInt() ??
          (meta['inquiries_count'] as num?)?.toInt() ??
          0,
      metadata: meta,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      storeName: store?['name'],
    );
  }

  String get actionTypeLabel {
    switch (actionType) {
      case 'engagement':
        return 'Engagement Medsos/Konten';
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
