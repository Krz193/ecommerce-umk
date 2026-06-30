class ProductImageModel {
  final String id;
  final String productId;
  final String imageUrl;
  final int sortOrder;

  ProductImageModel({
    required this.id,
    required this.productId,
    required this.imageUrl,
    required this.sortOrder,
  });

  factory ProductImageModel.fromJson(Map<String, dynamic> json) {
    return ProductImageModel(
      id: json['id'],
      productId: json['product_id'],
      imageUrl: json['image_url'],
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
