import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/product/models/product_review_model.dart';
import 'package:mobile/features/product/services/product_review_service.dart';

final productReviewServiceProvider = Provider<ProductReviewService>((ref) {
  return ProductReviewService();
});

final productReviewsProvider =
    FutureProvider.family<List<ProductReviewModel>, String>((
      ref,
      productId,
    ) async {
      final service = ref.watch(productReviewServiceProvider);
      return service.fetchProductReviews(productId);
    });

final productReviewStatsProvider = Provider.family<ProductReviewStats, String>((
  ref,
  productId,
) {
  final reviewsAsync = ref.watch(productReviewsProvider(productId));
  return reviewsAsync.maybeWhen(
    data: (reviews) => ProductReviewStats.fromReviews(reviews),
    orElse: () => ProductReviewStats(
      averageRating: 0.0,
      totalReviews: 0,
      ratingCounts: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    ),
  );
});

final orderProductReviewProvider =
    FutureProvider.family<
      ProductReviewModel?,
      ({String productId, String orderId})
    >((ref, arg) async {
      final service = ref.watch(productReviewServiceProvider);
      return service.fetchUserReviewForOrderProduct(
        productId: arg.productId,
        orderId: arg.orderId,
      );
    });
