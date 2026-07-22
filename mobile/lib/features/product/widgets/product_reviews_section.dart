import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ulasan Pembeli',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (stats.totalReviews > 0)
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${stats.averageRating}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' (${stats.totalReviews})',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          reviewsAsync.when(
            data: (reviews) {
              if (reviews.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Belum ada ulasan untuk produk ini.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  _buildRatingBreakdown(stats),
                  const Divider(height: 32),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 24),
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
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => Text('Gagal memuat ulasan: $err'),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBreakdown(ProductReviewStats stats) {
    return Column(
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
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.star, color: Colors.amber, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.amber,
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
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }),
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
              radius: 16,
              backgroundImage: review.userAvatarUrl != null
                  ? NetworkImage(review.userAvatarUrl!)
                  : null,
              child: review.userAvatarUrl == null
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.userName ?? 'Pembeli',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    DateFormatter.format(review.createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < review.rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        if (review.comment?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(review.comment!),
        ],
        if (review.sellerReply?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Respon Penjual',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.blue,
                      ),
                    ),
                    if (review.sellerRepliedAt != null)
                      Text(
                        DateFormatter.format(review.sellerRepliedAt!),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(review.sellerReply!, style: const TextStyle(fontSize: 13)),
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
              icon: const Icon(Icons.reply, size: 16),
              label: Text(
                review.sellerReply != null ? 'Edit Balasan' : 'Balas Ulasan',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
