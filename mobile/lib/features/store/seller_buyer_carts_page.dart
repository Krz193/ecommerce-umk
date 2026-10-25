import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerBuyerCartsPage extends ConsumerWidget {
  final String? storeId;

  const SellerBuyerCartsPage({super.key, this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managedStoreAsync = ref.watch(managedStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang Belanja Pembeli'),
      ),
      body: managedStoreAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal memuat toko: $err')),
        data: (managedStore) {
          final targetStoreId = storeId ?? managedStore?.id;
          if (targetStoreId == null || targetStoreId.isEmpty) {
            return const Center(
              child: Text('Belum ada toko UMK aktif.'),
            );
          }

          final insightsAsync = ref.watch(
            storeCartInsightsProvider(targetStoreId),
          );

          return insightsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Gagal memuat keranjang pembeli: $err'),
              ),
            ),
            data: (insights) {
              final totalItems =
                  (insights['total_items_in_carts'] as num?)?.toInt() ?? 0;
              final totalValue =
                  (insights['total_potential_value'] as num?)?.toInt() ?? 0;
              final uniqueBuyers =
                  (insights['unique_potential_buyers'] as num?)?.toInt() ?? 0;
              final products =
                  (insights['product_breakdown'] as List<dynamic>?) ?? [];
              final buyerCarts =
                  (insights['buyer_carts'] as List<dynamic>?) ?? [];

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(storeCartInsightsProvider(targetStoreId));
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.shopping_cart_checkout,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ringkasan Keranjang Pembeli Aktif',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSummaryMetric(
                                'Total Barang',
                                '$totalItems pcs',
                                Colors.blue.shade900,
                              ),
                              _buildSummaryMetric(
                                'Potensi Nilai',
                                CurrencyFormatter.format(totalValue),
                                Colors.green.shade700,
                              ),
                              _buildSummaryMetric(
                                'Calon Pembeli',
                                '$uniqueBuyers orang',
                                Colors.purple.shade700,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Daftar Keranjang per Pembeli',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (buyerCarts.isEmpty && products.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.remove_shopping_cart_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Belum ada produk toko yang disimpan di keranjang pembeli saat ini.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ...buyerCarts.map((raw) {
                        final cart = Map<String, dynamic>.from(raw as Map);
                        final buyerName =
                            cart['buyer_name'] as String? ?? 'Pembeli';
                        final buyerPhone = cart['buyer_phone'] as String?;
                        final buyerTotalItems =
                            (cart['total_items'] as num?)?.toInt() ?? 0;
                        final buyerTotalValue =
                            (cart['total_value'] as num?)?.toInt() ?? 0;
                        final updatedAt = cart['updated_at'] as String?;
                        final cartItems =
                            (cart['items'] as List<dynamic>?) ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            buyerName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          if (buyerPhone != null &&
                                              buyerPhone.isNotEmpty)
                                            Text(
                                              buyerPhone,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(
                                            buyerTotalValue,
                                          ),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                        Text(
                                          '$buyerTotalItems item',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                ...cartItems.map((rawItem) {
                                  final item = Map<String, dynamic>.from(
                                    rawItem as Map,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${item['product_name']} × ${item['quantity']}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(
                                            (item['subtotal'] as num?)
                                                    ?.toInt() ??
                                                0,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (updatedAt != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Terakhir diperbarui: ${DateFormatter.formatDateTime(updatedAt)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      const Text(
                        'Rekap Produk di Keranjang Pembeli',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...products.map((rawProd) {
                        final p = Map<String, dynamic>.from(rawProd as Map);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          title: Text(
                            p['product_name']?.toString() ?? 'Produk',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${p['total_quantity'] ?? 0} pcs di keranjang · ${p['unique_buyers'] ?? 0} calon pembeli · Stok: ${p['stock'] ?? 0}',
                          ),
                          trailing: Text(
                            CurrencyFormatter.format(
                              (p['total_potential_value'] as num?)?.toInt() ??
                                  0,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
