import 'package:mobile/features/product/models/product_image_model.dart';

class ProductModel {
  final String id;

  final String name;

  final int price;

  final int? originalPrice;

  final double discountPercent;

  final int discountAmount;

  final double taxPercent;

  final int stock;

  final String status;

  final String? description;

  final String? thumbnailUrl;

  final String storeId;

  final String? storeName;

  final String? storeCity;

  final String? categoryId;

  final String? categoryName;

  final String? productType;

  final String? size;

  final String? color;

  final List<ProductImageModel> images;

  bool get hasDiscount =>
      (originalPrice != null && originalPrice! > price) ||
      discountPercent > 0 ||
      discountAmount > 0;

  int get effectiveOriginalPrice =>
      (originalPrice != null && originalPrice! > price)
      ? originalPrice!
      : price;

  int get effectiveDiscountPercent {
    if (discountPercent > 0) return discountPercent.round();
    if (originalPrice != null && originalPrice! > price && originalPrice! > 0) {
      return (((originalPrice! - price) / originalPrice!) * 100).round();
    }
    return 0;
  }

  /// Broadened product search (#7): matches name, description, category,
  /// UMK store name, store city/address, product type, color, size, and promo status.
  bool matchesSearchQuery(String rawQuery) {
    final normalized = rawQuery.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final searchableBlob = [
      name,
      description ?? '',
      categoryName ?? '',
      storeName ?? '',
      storeCity ?? '',
      productType ?? '',
      color ?? '',
      size ?? '',
      if (hasDiscount) 'diskon promo sale hemat potongan',
    ].join(' ').toLowerCase();

    return tokens.every((token) => searchableBlob.contains(token));
  }

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.originalPrice,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.taxPercent = 0,
    required this.stock,
    required this.status,
    this.description,
    this.thumbnailUrl,
    required this.storeId,
    this.storeName,
    this.storeCity,
    this.categoryId,
    this.categoryName,
    this.productType,
    this.size,
    this.color,
    this.images = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawImages = json['product_images'];
    final category = json['category'];
    final store = json['store'] ?? json['stores'];

    return ProductModel(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toInt(),
      originalPrice: (json['original_price'] as num?)?.toInt(),
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toInt() ?? 0,
      taxPercent: (json['tax_percent'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num).toInt(),
      status: json['status'],
      description: json['description'],
      thumbnailUrl: json['thumbnail_url'],
      storeId: json['store_id'],
      storeName: store is Map ? store['name'] as String? : null,
      storeCity: store is Map ? (store['address'] as String?) : null,
      categoryId: json['category_id'],
      categoryName: category is Map ? category['name'] : null,
      productType: json['product_type'],
      size: json['size'],
      color: json['color'],
      images: rawImages is List
          ? rawImages
                .map<ProductImageModel>(
                  (image) => ProductImageModel.fromJson(image),
                )
                .toList()
          : const [],
    );
  }
}
