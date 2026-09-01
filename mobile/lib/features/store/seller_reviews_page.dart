import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/product/models/product_review_model.dart';
import 'package:mobile/features/product/providers/product_review_providers.dart';
import 'package:mobile/features/product/widgets/seller_reply_dialog.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

final storeReviewsProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, storeId) async {
      final response = await supabase
          .from('product_reviews')
          .select('''
        *,
        user:users (
          id,
          full_name,
          avatar_url
        ),
        product:products!inner (
          id,
          name,
          store_id
        )
      ''')
          .eq('products.store_id', storeId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    });

class SellerReviewsPage extends ConsumerWidget {
  const SellerReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(managedStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ulasan Toko UMK',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Gagal memuat toko: $err')),
        data: (store) {
          if (store == null) {
            return const Center(
              child: Text('Belum ada toko UMK yang dipilih atau dikelola.'),
            );
          }

          final reviewsAsync = ref.watch(storeReviewsProvider(store.id));

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.surface,
                child: Row(
                  children: [
                    const Icon(Icons.store, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Mengelola Ulasan Pembeli untuk Toko Ini',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: reviewsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) =>
                      Center(child: Text('Gagal memuat ulasan: $err')),
                  data: (rawReviews) {
                    if (rawReviews.isEmpty) {
                      return const Center(
                        child: Text(
                          'Belum ada ulasan pembeli untuk produk toko ini.',
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rawReviews.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (ctx, index) {
                        final raw = rawReviews[index];
                        final review = ProductReviewModel.fromJson(raw);
                        final productMap =
                            raw['product'] as Map<String, dynamic>? ?? {};
                        final productName = productMap['name'] ?? 'Produk UMK';
                        final displayName = review.userName ?? 'Pembeli';

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      child: Text(
                                        displayName.isNotEmpty
                                            ? displayName[0].toUpperCase()
                                            : 'P',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Produk: $productName',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
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
                                              : Icons.star_border_rounded,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (review.comment != null &&
                                    review.comment!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    review.comment!,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                                if (review.sellerReply != null &&
                                    review.sellerReply!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Balasan Penjual / Asisten UMK:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          review.sellerReply!,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Switch(
                                          value: review.isApproved,
                                          onChanged: (val) async {
                                            try {
                                              await ref
                                                  .read(productReviewServiceProvider)
                                                  .toggleReviewApproval(
                                                    reviewId: review.id,
                                                    isApproved: val,
                                                  );
                                              ref.invalidate(storeReviewsProvider(store.id));
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(e.toString())),
                                                );
                                              }
                                            }
                                          },
                                          activeThumbColor: AppColors.primary,
                                        ),
                                        Text(
                                          review.isApproved ? 'Tampil' : 'Sembunyi',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: review.isApproved
                                                ? AppColors.primary
                                                : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.reply, size: 16),
                                      label: Text(
                                        review.sellerReply == null
                                            ? 'Balas Ulasan'
                                            : 'Edit Balasan',
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) =>
                                              SellerReplyDialog(review: review),
                                        ).then((_) {
                                          ref.invalidate(
                                            storeReviewsProvider(store.id),
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
