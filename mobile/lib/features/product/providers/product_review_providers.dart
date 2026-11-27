import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/product/models/product_review_model.dart';
import 'package:mobile/features/product/services/product_review_service.dart';

typedef ProductRatingSummary = ({double averageRating, int totalReviews});

final productReviewServiceProvider = Provider<ProductReviewService>((ref) {
  return ProductReviewService();
});

final allProductReviewStatsProvider =
    FutureProvider<Map<String, ProductRatingSummary>>((ref) async {
      final response = await supabase
          .from('product_reviews')
          .select('product_id, rating')
          .eq('is_approved', true);

      final grouped = <String, List<int>>{};
      for (final row in response as List) {
        final productId = row['product_id']?.toString();
        final rating = (row['rating'] as num?)?.toInt();
        if (productId == null || productId.isEmpty || rating == null) continue;
        grouped.putIfAbsent(productId, () => []).add(rating);
      }

      return grouped.map((productId, ratings) {
        final total = ratings.length;
        final sum = ratings.fold<int>(0, (acc, r) => acc + r);
        final avg = double.parse((sum / total).toStringAsFixed(1));
        return MapEntry(productId, (averageRating: avg, totalReviews: total));
      });
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
