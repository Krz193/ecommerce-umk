import 'package:mobile/features/product/models/product_image_model.dart';

class ProductModel {
  final String id;

  final String name;

  final int price;

  final int stock;

  final String status;

  final String? description;

  final String? thumbnailUrl;

  final String storeId;

  final String? categoryId;

  final String? categoryName;

  final String? productType;

  final String? size;

  final String? color;

  final List<ProductImageModel> images;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.status,
    this.description,
    this.thumbnailUrl,
    required this.storeId,
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

    return ProductModel(
      id: json['id'],
      name: json['name'],

      price: (json['price'] as num).toInt(),

      stock: (json['stock'] as num).toInt(),

      status: json['status'],

      description: json['description'],

      thumbnailUrl: json['thumbnail_url'],

      storeId: json['store_id'],

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
