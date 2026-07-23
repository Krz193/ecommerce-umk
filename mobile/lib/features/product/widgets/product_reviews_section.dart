import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/product/models/product_review_model.dart';
import 'package:mobile/features/product/providers/product_review_providers.dart';
import 'package:mobile/features/product/widgets/seller_reply_dialog.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class ProductReviewsSection extends ConsumerWidget {
  final String productId;
  final String storeId;

  const ProductReviewsSection({
    super.key,
    required this.productId,
    required this.storeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(productReviewsProvider(productId));
    final stats = ref.watch(productReviewStatsProvider(productId));
    final storeAsync = ref.watch(publicStoreProvider(storeId));
    final currentUserId = supabase.auth.currentUser?.id;

    final isStoreOwner = storeAsync.maybeWhen(
      data: (store) => store.ownerId == currentUserId,
      orElse: () => false,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rate_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Ulasan Pembeli',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (stats.totalReviews > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: Colors.amber.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${stats.averageRating}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryHover,
                        ),
                      ),
                      Text(
                        ' (${stats.totalReviews})',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          reviewsAsync.when(
            data: (reviews) {
              if (reviews.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: const Column(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        color: AppColors.textMuted,
                        size: 36,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Belum ada ulasan untuk produk ini.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  _buildRatingBreakdown(stats),
                  const Divider(height: 32, color: Color(0xFFF1F5F9)),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      return _buildReviewItem(
                        context,
                        ref,
                        review,
                        isStoreOwner,
                      );
                    },
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (err, stack) => Text('Gagal memuat ulasan: $err'),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBreakdown(ProductReviewStats stats) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(5, (index) {
          final starLevel = 5 - index;
          final count = stats.ratingCounts[starLevel] ?? 0;
          final percentage = stats.totalReviews > 0
              ? count / stats.totalReviews
              : 0.0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(
                  '$starLevel',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.star_rounded,
                  color: Colors.amber.shade700,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.amber.shade600,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildReviewItem(
    BuildContext context,
    WidgetRef ref,
    ProductReviewModel review,
    bool isStoreOwner,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: review.userAvatarUrl != null
                  ? NetworkImage(review.userAvatarUrl!)
                  : null,
              child: review.userAvatarUrl == null
                  ? const Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: AppColors.primary,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.userName ?? 'Pembeli',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    DateFormatter.format(review.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber.shade700,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        if (review.comment?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            review.comment!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
        if (review.sellerReply?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Respon Penjual',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.primaryHover,
                          ),
                        ),
                      ],
                    ),
                    if (review.sellerRepliedAt != null)
                      Text(
                        DateFormatter.format(review.sellerRepliedAt!),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  review.sellerReply!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (isStoreOwner) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => SellerReplyDialog(review: review),
                );
              },
              icon: const Icon(Icons.reply_rounded, size: 16),
              label: Text(
                review.sellerReply != null ? 'Edit Balasan' : 'Balas Ulasan',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
