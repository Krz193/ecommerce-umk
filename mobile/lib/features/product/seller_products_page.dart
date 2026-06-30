import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/product/models/product_model.dart';
import 'package:mobile/features/product/providers/product_provider.dart';
import 'package:mobile/features/product/providers/seller_product_provider.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerProductsPage extends ConsumerStatefulWidget {
  const SellerProductsPage({super.key});

  @override
  ConsumerState<SellerProductsPage> createState() => _SellerProductsPageState();
}

class _SellerProductsPageState extends ConsumerState<SellerProductsPage> {
  String? updatingProductId;

  Future<void> adjustStock(ProductModel product, int delta) async {
    final nextStock = product.stock + delta;

    if (nextStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock cannot be below zero')),
      );

      return;
    }

    setState(() {
      updatingProductId = product.id;
    });

    try {
      final sellerProductService = ref.read(sellerProductServiceProvider);

      await sellerProductService.updateProductStock(
        productId: product.id,
        storeId: product.storeId,
        stock: nextStock,
      );

      ref.invalidate(sellerProductsProvider(product.storeId));
      ref.invalidate(productsProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Stock updated to $nextStock')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          updatingProductId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),

      floatingActionButton: storeAsync.maybeWhen(
        data: (store) {
          if (store == null) {
            return null;
          }

          return FloatingActionButton(
            onPressed: () {
              context.push('/seller/products/create');
            },
            child: const Icon(Icons.add),
          );
        },
        orElse: () => null,
      ),

      body: storeAsync.when(
        data: (store) {
          if (store == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create a store before adding products',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.go('/seller/onboarding');
                      },
                      child: const Text('Create Store'),
                    ),
                  ],
                ),
              ),
            );
          }

          final productsAsync = ref.watch(sellerProductsProvider(store.id));

          return productsAsync.when(
            data: (products) {
              if (products.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'No products yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.push('/seller/products/create');
                          },
                          child: const Text('Add Product'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(sellerProductsProvider(store.id));
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return buildProductCard(products[index]);
                  },
                ),
              );
            },
            error: (error, stackTrace) {
              return Center(child: Text(error.toString()));
            },
            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
          );
        },
        error: (error, stackTrace) {
          return Center(child: Text(error.toString()));
        },
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget buildProductCard(ProductModel product) {
    final isUpdating = updatingProductId == product.id;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        context.push('/seller/products/${product.id}/edit');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (product.thumbnailUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      product.thumbnailUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 72,
                          height: 72,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(product.status),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 8),
            Text(CurrencyFormatter.format(product.price)),
            if (product.categoryName != null) ...[
              const SizedBox(height: 8),
              Text('Category: ${product.categoryName}'),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                buildStockBadge(product.stock),
                const Spacer(),
                IconButton(
                  tooltip: 'Reduce stock',
                  onPressed: isUpdating
                      ? null
                      : () {
                          adjustStock(product, -1);
                        },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 48,
                  child: Center(
                    child: isUpdating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            product.stock.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                IconButton(
                  tooltip: 'Add stock',
                  onPressed: isUpdating
                      ? null
                      : () {
                          adjustStock(product, 1);
                        },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStockBadge(int stock) {
    final (label, color) = switch (stock) {
      0 => ('Out of stock', Colors.red),
      <= 5 => ('Low stock', Colors.orange),
      _ => ('In stock', Colors.green),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
