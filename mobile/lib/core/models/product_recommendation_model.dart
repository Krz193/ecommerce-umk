import 'package:mobile/features/product/models/product_model.dart';

class ProductRecommendationModel {
  final String id;
  final String productId;
  final int priority;
  final String? badgeText;
  final bool isActive;
  final DateTime createdAt;
  final ProductModel? product;

  ProductRecommendationModel({
    required this.id,
    required this.productId,
    this.priority = 0,
    this.badgeText,
    this.isActive = true,
    required this.createdAt,
    this.product,
  });

  factory ProductRecommendationModel.fromJson(Map<String, dynamic> json) {
    return ProductRecommendationModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      priority: json['priority'] as int? ?? 0,
      badgeText: json['badge_text'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      product: json['product'] != null 
          ? ProductModel.fromJson(json['product']) 
          : null,
    );
  }
}
