import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
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
                          final hasMedia = item.mediaUrls.isNotEmpty;
                          final hasProduct = item.productId != null &&
                              item.productId!.isNotEmpty;

                          return Container(
                            width: 280,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Cover Image Preview if available
                                if (hasMedia)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      item.mediaUrls.first,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const SizedBox.shrink(),
                                    ),
                                  ),

                                // Dark Overlay Gradient
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
                                      // Top Content Type Badge
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                          const Spacer(),
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
                                        style: const TextStyle(
                                          color: Colors.white,
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
                                          style: const TextStyle(
                                            color: Colors.white70,
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

                                      // CTA Action InkWell
                                      SizedBox(
                                        width: double.infinity,
                                        height: 34,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            if (hasProduct) {
                                              context.push(
                                                '/products/${item.productId}',
                                              );
                                            }
                                          },
                                          icon: Icon(
                                            hasProduct
                                                ? Icons.shopping_cart_outlined
                                                : Icons.arrow_forward_rounded,
                                            size: 14,
                                          ),
                                          label: Text(
                                            hasProduct
                                                ? 'Lihat Produk 🛒'
                                                : 'Lihat Promo',
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

                return Column(
                  children: products.map((product) {
                    return buildProductCard(context, product);
                  }).toList(),
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
            Text('Phone: ${store.phone}'),
          ],
          if (store.address?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Address: ${store.address}'),
          ],
        ],
      ),
    );
  }

  Widget buildProductCard(BuildContext context, ProductModel product) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        context.push('/products/${product.id}');
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.thumbnailUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  product.thumbnailUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 160,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Text('Image unavailable'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              product.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(CurrencyFormatter.format(product.price)),
            const SizedBox(height: 4),
            Text(
              product.stock > 0 ? 'Stock: ${product.stock}' : 'Out of stock',
            ),
            if (product.categoryName != null) ...[
              const SizedBox(height: 4),
              Text(product.categoryName!),
            ],
          ],
        ),
      ),
    );
  }
}
