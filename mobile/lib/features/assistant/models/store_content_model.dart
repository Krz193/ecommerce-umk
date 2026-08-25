class StoreContentModel {
  final String id;
  final String storeId;
  final String createdBy;
  final String title;
  final String contentType;
  final String? body;
  final List<String> mediaUrls;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? storeName;
  final String? productId;
  final String? productName;
  final int? productPrice;
  final String? productThumbnailUrl;

  StoreContentModel({
    required this.id,
    required this.storeId,
    required this.createdBy,
    required this.title,
    required this.contentType,
    this.body,
    required this.mediaUrls,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.storeName,
    this.productId,
    this.productName,
    this.productPrice,
    this.productThumbnailUrl,
  });

  factory StoreContentModel.fromMap(Map<String, dynamic> map) {
    final store = map['stores'] as Map<String, dynamic>?;
    final product = map['products'] as Map<String, dynamic>?;
    final media = map['media_urls'];
    List<String> parsedMedia = [];
    if (media is List) {
      parsedMedia = media.map((e) => e.toString()).toList();
    }

    return StoreContentModel(
      id: map['id'] ?? '',
      storeId: map['store_id'] ?? '',
      createdBy: map['created_by'] ?? '',
      title: map['title'] ?? '',
      contentType: map['content_type'] ?? 'promo',
      body: map['body'],
      mediaUrls: parsedMedia,
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
      storeName: store?['name'],
      productId: map['product_id'] ?? product?['id'],
      productName: product?['name'],
      productPrice: product?['price'] is int
          ? product!['price'] as int
          : (product?['price'] != null
                ? int.tryParse(product!['price'].toString())
                : null),
      productThumbnailUrl: product?['thumbnail_url'],
    );
  }

  String? get displayCoverUrl {
    if (mediaUrls.isNotEmpty && mediaUrls.first.isNotEmpty) {
      return mediaUrls.first;
    }
    if (productThumbnailUrl != null && productThumbnailUrl!.isNotEmpty) {
      return productThumbnailUrl;
    }
    return null;
  }

  String get contentTypeLabel {
    switch (contentType) {
      case 'banner':
        return 'Banner Spanduk/Situs';
      case 'promo':
        return 'Promosi Diskon/Penawaran';
      case 'storytelling':
        return 'Kisah Produk/UMK';
      case 'social':
        return 'Post Media Sosial';
      case 'educational':
        return 'Materi Edukasi UMK';
      default:
        return 'Konten UMK';
    }
  }
}
