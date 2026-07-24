import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/assistant/models/store_content_model.dart';
import 'package:mobile/features/explore/explore_providers.dart';
import 'package:mobile/features/product/models/product_model.dart';
import 'package:mobile/features/store/models/store_model.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class StorePublicPage extends ConsumerWidget {
  final String storeId;

  const StorePublicPage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(publicStoreProvider(storeId));
    final productsAsync = ref.watch(publicStoreProductsProvider(storeId));
    final contentsAsync = ref.watch(storePublicContentsProvider(storeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Toko UMK')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(publicStoreProvider(storeId));
          ref.invalidate(publicStoreProductsProvider(storeId));
          ref.invalidate(storePublicContentsProvider(storeId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            storeAsync.when(
              data: (store) => buildStoreHeader(store),
              error: (error, stackTrace) => Text(error.toString()),
              loading: () => const LinearProgressIndicator(),
            ),
            const SizedBox(height: 16),

            // Store Promos & Contents Section
            contentsAsync.when(
              data: (contents) {
                if (contents.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Promosi & Konten Toko 📢',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: contents.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final item = contents[index];
                          final hasProduct = item.productId != null &&
                              item.productId!.isNotEmpty;

                          final coverUrl = item.displayCoverUrl;
                          final hasPhoto = coverUrl != null;

                          return Container(
                            width: 280,
                            decoration: BoxDecoration(
                              color: hasPhoto
                                  ? const Color(0xFF0F172A)
                                  : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: hasPhoto
                                    ? Colors.transparent
                                    : AppColors.primary.withAlpha(60),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Cover Image Preview or Flat Vector Icon Placeholder
                                if (hasPhoto)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      coverUrl,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const SizedBox.shrink(),
                                    ),
                                  )
                                else
                                  Positioned(
                                    right: -10,
                                    bottom: -10,
                                    child: Icon(
                                      item.contentType == 'promo'
                                          ? Icons.local_offer_rounded
                                          : item.contentType == 'storytelling'
                                              ? Icons.auto_stories_rounded
                                              : Icons.campaign_rounded,
                                      size: 110,
                                      color: AppColors.primary.withAlpha(35),
                                    ),
                                  ),

                                // Dark Overlay Gradient (Only on photo)
                                if (hasPhoto)
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withAlpha(210),
                                          Colors.black.withAlpha(80),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                    ),
                                  ),

                                // Content Details & CTA
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Top Content Type & Promo Badges (Wrap to prevent overflow)
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              item.contentTypeLabel,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (hasProduct)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade700,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'PROMO PRODUK 🏷️',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const Spacer(),

                                      // Content Title & Body Snippet
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          color: hasPhoto
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.body != null &&
                                          item.body!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.body!,
                                          style: TextStyle(
                                            color: hasPhoto
                                                ? Colors.white70
                                                : AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 10),

                                      // Linked Product Info & Direct CTA Button
                                      if (hasProduct) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withAlpha(230),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.shopping_bag_outlined,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  item.productName ??
                                                      'Produk UMK',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.black87,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (item.productPrice != null)
                                                Text(
                                                  CurrencyFormatter.format(
                                                    item.productPrice!,
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],

                                      // CTA Action Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: 34,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            if (hasProduct) {
                                              context.push(
                                                '/products/${item.productId}',
                                              );
                                            } else {
                                              _showContentDetailModal(
                                                context,
                                                item,
                                              );
                                            }
                                          },
                                          icon: Icon(
                                            hasProduct
                                                ? Icons.shopping_cart_outlined
                                                : Icons.article_outlined,
                                            size: 14,
                                          ),
                                          label: Text(
                                            hasProduct
                                                ? 'Lihat Produk 🛒'
                                                : 'Detail Promosi',
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
              error: (err, stack) => const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
            ),

            const Text(
              'Produk Toko',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: Text('Belum ada produk yang dipublikasi'),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.70,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return buildProductCard(context, products[index]);
                  },
                );
              },
              error: (error, stackTrace) => Text(error.toString()),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStoreHeader(StoreModel store) {
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
          Text(
            store.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (store.description?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(store.description!),
          ],
          if (store.phone?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Telepon: ${store.phone}'),
          ],
          if (store.address?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Alamat: ${store.address}'),
          ],
        ],
      ),
    );
  }

  Widget buildProductCard(BuildContext context, ProductModel product) {
    return GestureDetector(
      onTap: () {
        context.push('/products/${product.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: product.thumbnailUrl != null
                        ? Image.network(
                            product.thumbnailUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade100,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: AppColors.textMuted,
                                  size: 32,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_outlined,
                              color: AppColors.textMuted,
                              size: 32,
                            ),
                          ),
                  ),
                  if (product.stock <= 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Habis',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.categoryName != null) ...[
                    Text(
                      product.categoryName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryHover,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.format(product.price),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.stock > 0 ? 'Stok: ${product.stock}' : 'Stok Habis',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContentDetailModal(BuildContext context, StoreContentModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.contentTypeLabel,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormatter.format(item.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.storeName ?? 'Toko UMK',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (item.mediaUrls.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        item.mediaUrls.first,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (item.body != null && item.body!.isNotEmpty) ...[
                    Text(
                      item.body!,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Tutup Detail'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
