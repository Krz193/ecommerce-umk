import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Store')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(publicStoreProvider(storeId));
          ref.invalidate(publicStoreProductsProvider(storeId));
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
            const Text(
              'Products',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: Text('No published products')),
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
