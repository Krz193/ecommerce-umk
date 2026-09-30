import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/product/models/product_model.dart';
import 'package:mobile/features/product/providers/seller_product_provider.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerProductsPage extends ConsumerStatefulWidget {
  const SellerProductsPage({super.key});

  @override
  ConsumerState<SellerProductsPage> createState() => _SellerProductsPageState();
}

class _SellerProductsPageState extends ConsumerState<SellerProductsPage> {
  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(managedStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Produk Toko')),

      floatingActionButton: storeAsync.maybeWhen(
        data: (store) {
          if (store == null) {
            return null;
          }

          return FloatingActionButton.extended(
            onPressed: () {
              context.push('/seller/products/create');
            },
            icon: const Icon(Icons.add),
            label: const Text('Tambah Produk'),
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
                      'Buka atau daftarkan toko terlebih dahulu sebelum menambahkan produk.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.go('/seller/onboarding');
                      },
                      child: const Text('Buka Toko UMK Sekarang'),
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
                          'Belum Ada Produk Ditambahkan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Mulai tambahkan produk jualan toko Anda agar pembeli dapat melihat dan memesan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            context.push('/seller/products/create');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah Produk Pertama'),
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
    final statusLabel = switch (product.status) {
      'published' => 'Aktif',
      'draft' => 'Draf',
      'archived' => 'Diarsipkan',
      _ => product.status,
    };
    final statusColor = switch (product.status) {
      'published' => Colors.green,
      'draft' => Colors.orange,
      _ => Colors.grey,
    };

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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              CurrencyFormatter.format(product.price),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            if (product.categoryName != null) ...[
              const SizedBox(height: 6),
              Text(
                'Kategori: ${product.categoryName}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            if (hasCharacteristics(product)) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (product.productType?.isNotEmpty == true)
                    Chip(label: Text('Jenis: ${product.productType}')),
                  if (product.size?.isNotEmpty == true)
                    Chip(label: Text('Ukuran: ${product.size}')),
                  if (product.color?.isNotEmpty == true)
                    Chip(label: Text('Warna: ${product.color}')),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                buildStockBadge(product.stock),
                Text(
                  'Sisa stok: ${product.stock} pcs',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    context.push('/seller/products/${product.id}/edit');
                  },
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Kelola & Ubah'),
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
      0 => ('Stok Habis', Colors.red),
      <= 5 => ('Stok Menipis', Colors.orange),
      _ => ('Stok Aman', Colors.green),
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

  bool hasCharacteristics(ProductModel product) {
    return product.productType?.isNotEmpty == true ||
        product.size?.isNotEmpty == true ||
        product.color?.isNotEmpty == true;
  }
}
