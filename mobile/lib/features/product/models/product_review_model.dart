class ProductReviewModel {
  final String id;
  final String productId;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final String orderId;
  final int rating;
  final String? comment;
  final String? sellerReply;
  final DateTime? sellerRepliedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductReviewModel({
    required this.id,
    required this.productId,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    required this.orderId,
    required this.rating,
    this.comment,
    this.sellerReply,
    this.sellerRepliedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductReviewModel.fromJson(Map<String, dynamic> json) {
    final rawUser = json['users'];
    String? name;
    String? avatar;
    if (rawUser is Map<String, dynamic>) {
      name = rawUser['full_name'];
      avatar = rawUser['avatar_url'];
    }

    return ProductReviewModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      userId: json['user_id'] as String,
      userName: name,
      userAvatarUrl: avatar,
      orderId: json['order_id'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      sellerReply: json['seller_reply'] as String?,
      sellerRepliedAt: json['seller_replied_at'] != null
          ? DateTime.parse(json['seller_replied_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ProductReviewStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingCounts;

  ProductReviewStats({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingCounts,
  });

  factory ProductReviewStats.fromReviews(List<ProductReviewModel> reviews) {
    if (reviews.isEmpty) {
      return ProductReviewStats(
        averageRating: 0.0,
        totalReviews: 0,
        ratingCounts: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      );
    }

    final counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    int totalRating = 0;

    for (final review in reviews) {
      totalRating += review.rating;
      counts[review.rating] = (counts[review.rating] ?? 0) + 1;
    }

    final avg = totalRating / reviews.length;

    return ProductReviewStats(
      averageRating: double.parse(avg.toStringAsFixed(1)),
      totalReviews: reviews.length,
      ratingCounts: counts,
    );
  }
}
