import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/order/models/order_model.dart';
import 'package:mobile/features/order/providers/seller_order_provider.dart';
import 'package:mobile/features/product/models/product_model.dart';
import 'package:mobile/features/product/providers/seller_product_provider.dart';
import 'package:mobile/features/store/models/store_model.dart';
import 'package:mobile/features/store/providers/store_provider.dart';
import 'package:mobile/features/store/seller_reviews_page.dart';

class SellerStoreDashboardPage extends ConsumerWidget {
  const SellerStoreDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toko Saya'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }

            context.go('/account');
          },
        ),
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
                      'Belum Ada Toko Terdaftar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myStoreProvider);
            },

            child: ListView(
              padding: const EdgeInsets.all(16),

              children: [
                _buildStoreSummary(store, ref),

                const SizedBox(height: 16),

                _buildActionTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Kelola Produk',
                  subtitle: 'Atur katalog produk dan stok barang toko',
                  onTap: () {
                    context.push('/seller/products');
                  },
                ),

                const SizedBox(height: 12),

                _buildActionTile(
                  icon: Icons.analytics_outlined,
                  title: 'Laporan Toko',
                  subtitle:
                      'Pantau ringkasan penjualan, transaksi, dan performa',
                  onTap: () {
                    context.push('/seller/reports');
                  },
                ),

                const SizedBox(height: 12),

                _buildActionTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Pesanan Masuk',
                  subtitle: 'Kelola dan proses pesanan dari pembeli',
                  onTap: () {
                    context.push('/seller/orders');
                  },
                ),

                const SizedBox(height: 12),

                _buildActionTile(
                  icon: Icons.star_outline_rounded,
                  title: 'Ulasan & Rating Toko',
                  subtitle: 'Kelola ulasan pembeli dan balas komentar',
                  onTap: () {
                    context.push('/seller/reviews');
                  },
                ),
              ],
            ),
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
}

class SellerStoreReportsPage extends ConsumerWidget {
  const SellerStoreReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan Toko'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }

            context.go('/seller/store');
          },
        ),
      ),
      body: storeAsync.when(
        data: (store) {
          if (store == null) {
            return const Center(child: Text('Belum ada toko'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sellerProductsProvider(store.id));
              ref.invalidate(sellerOrdersProvider(store.id));
              ref.invalidate(storeCartInsightsProvider(store.id));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildReportHeader(store),
                const SizedBox(height: 16),
                _buildDashboardMetrics(context, ref, store.id, store.name),
              ],
            ),
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

  Widget _buildReportHeader(StoreModel store) {
    return Container(
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
          const SizedBox(height: 8),
          const Text(
            'Ringkasan operasional toko, data barang, laporan keuangan, pelanggan, pengiriman, dan stok menipis.',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMetrics(
    BuildContext context,
    WidgetRef ref,
    String storeId,
    String storeName,
  ) {
    final productsAsync = ref.watch(sellerProductsProvider(storeId));
    final ordersAsync = ref.watch(sellerOrdersProvider(storeId));

    return productsAsync.when(
      data: (products) {
        return ordersAsync.when(
          data: (orders) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildExportPanel(context, storeName, products, orders),
                const SizedBox(height: 12),
                _buildCartInsights(context, ref, storeId),
                const SizedBox(height: 12),
                _buildProductMetrics(products),
                const SizedBox(height: 12),
                _buildGoodsReport(products),
                const SizedBox(height: 12),
                _buildOrderMetrics(orders),
                const SizedBox(height: 12),
                _buildFinancialReport(orders),
                const SizedBox(height: 12),
                _buildBuyerReport(orders),
                const SizedBox(height: 12),
                _buildShipmentReport(orders),
                const SizedBox(height: 12),
                _buildLowStockAlerts(context, products),
              ],
            );
          },
          error: (error, stackTrace) {
            return _buildMetricError(error);
          },
          loading: () {
            return const LinearProgressIndicator();
          },
        );
      },
      error: (error, stackTrace) {
        return _buildMetricError(error);
      },
      loading: () {
        return const LinearProgressIndicator();
      },
    );
  }

  Widget _buildCartInsights(BuildContext context, WidgetRef ref, String storeId) {
    final insightsAsync = ref.watch(storeCartInsightsProvider(storeId));

    return insightsAsync.when(
      data: (insights) {
        final totalItems = insights['total_items_in_carts'] ?? 0;
        final totalValue = insights['total_potential_value'] ?? 0;
        final uniqueBuyers = insights['unique_potential_buyers'] ?? 0;
        final breakdown = (insights['product_breakdown'] as List<dynamic>?) ?? [];

        return Container(
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
                  const Icon(Icons.shopping_cart_checkout, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Potensi Keranjang Pembeli',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricItem(
                    title: 'Total Barang',
                    value: totalItems.toString(),
                    color: Colors.blue.shade900,
                  ),
                  _buildMetricItem(
                    title: 'Potensi Nilai',
                    value: CurrencyFormatter.format(totalValue),
                    color: Colors.green.shade700,
                  ),
                  _buildMetricItem(
                    title: 'Calon Pembeli',
                    value: uniqueBuyers.toString(),
                    color: Colors.purple.shade700,
                  ),
                ],
              ),
              if (totalItems > 0 && breakdown.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: Colors.blue.shade100, height: 1),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _showProductBreakdownSheet(context, breakdown),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 16, color: Colors.blue.shade800),
                            const SizedBox(width: 6),
                            Text(
                              'Lihat Rincian ${breakdown.length} Produk di Keranjang',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 13, color: Colors.blue.shade800),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showProductBreakdownSheet(
    BuildContext context,
    List<dynamic> items,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shopping_cart_outlined,
                            color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rincian Produk di Keranjang',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Produk toko yang sedang disimpan calon pembeli',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index] as Map<String, dynamic>;
                      final name = item['product_name'] ?? 'Produk';
                      final imageUrl = item['product_image'] as String?;
                      final price = (item['price'] as num?)?.toInt() ?? 0;
                      final stock = (item['stock'] as num?)?.toInt() ?? 0;
                      final totalQty = (item['total_quantity'] as num?)?.toInt() ?? 0;
                      final totalValue = (item['total_potential_value'] as num?)?.toInt() ?? 0;
                      final buyerCount = (item['unique_buyers'] as num?)?.toInt() ?? 0;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        width: 56,
                                        height: 56,
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.inventory_2_outlined,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 56,
                                      height: 56,
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.inventory_2_outlined,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyFormatter.format(price),
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$totalQty di keranjang',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$buyerCount calon pembeli',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.purple.shade800,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Stok: $stock',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Potensi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.format(totalValue),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildExportPanel(
    BuildContext context,
    String storeName,
    List<ProductModel> products,
    List<OrderModel> orders,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unduh Laporan Toko (Excel / CSV)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Unduh data laporan lengkap yang dapat langsung dibuka di Microsoft Excel atau Google Spreadsheet.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  _exportGoodsReport(context, storeName, products);
                },
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Data Barang'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _exportFinancialReport(context, storeName, orders);
                },
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Keuangan'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _exportBuyerReport(context, storeName, orders);
                },
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text('Pelanggan'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _exportShipmentReport(context, storeName, orders);
                },
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Pengiriman'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportGoodsReport(
    BuildContext context,
    String storeName,
    List<ProductModel> products,
  ) async {
    final rows = [
      [
        'Product ID',
        'Product Name',
        'Category',
        'Type',
        'Size',
        'Color',
        'Status',
        'Price',
        'Current Stock',
        'Stock Value',
        'Low Stock',
      ],
      ...products.map((product) {
        return [
          product.id,
          product.name,
          product.categoryName ?? '',
          product.productType ?? '',
          product.size ?? '',
          product.color ?? '',
          product.status,
          product.price.toString(),
          product.stock.toString(),
          (product.price * product.stock).toString(),
          product.stock <= 5 ? 'yes' : 'no',
        ];
      }),
    ];

    await _writeCsvReport(context, storeName, 'goods-report', rows);
  }

  Future<void> _exportFinancialReport(
    BuildContext context,
    String storeName,
    List<OrderModel> orders,
  ) async {
    final rows = [
      [
        'Order ID',
        'Order Number',
        'Buyer',
        'Payment Status',
        'Order Status',
        'Total Amount',
        'Created At',
      ],
      ...orders.map((order) {
        return [
          order.id,
          order.orderNumber,
          order.shippingName ?? '',
          order.paymentStatus,
          order.status,
          order.totalAmount.toString(),
          order.createdAt.toIso8601String(),
        ];
      }),
    ];

    await _writeCsvReport(context, storeName, 'financial-report', rows);
  }

  Future<void> _exportBuyerReport(
    BuildContext context,
    String storeName,
    List<OrderModel> orders,
  ) async {
    final buyers = <String, _BuyerReportRow>{};

    for (final order in orders) {
      final buyerKey = order.userId ?? order.shippingName ?? 'unknown';
      final buyer = buyers.putIfAbsent(
        buyerKey,
        () => _BuyerReportRow(
          buyerKey: buyerKey,
          buyerName: order.shippingName ?? 'Unknown buyer',
        ),
      );

      buyer.orderCount += 1;
      buyer.lastOrderAt =
          buyer.lastOrderAt == null ||
              order.createdAt.isAfter(buyer.lastOrderAt!)
          ? order.createdAt
          : buyer.lastOrderAt;

      if (order.paymentStatus == 'paid') {
        buyer.paidOrderCount += 1;
        buyer.totalSpend += order.totalAmount;
      }
    }

    final rows = [
      [
        'Buyer Key',
        'Buyer Name',
        'Order Count',
        'Paid Order Count',
        'Total Paid Spend',
        'Last Order At',
      ],
      ...buyers.values.map((buyer) {
        return [
          buyer.buyerKey,
          buyer.buyerName,
          buyer.orderCount.toString(),
          buyer.paidOrderCount.toString(),
          buyer.totalSpend.toString(),
          buyer.lastOrderAt?.toIso8601String() ?? '',
        ];
      }),
    ];

    await _writeCsvReport(context, storeName, 'buyer-report', rows);
  }

  Future<void> _exportShipmentReport(
    BuildContext context,
    String storeName,
    List<OrderModel> orders,
  ) async {
    final rows = [
      [
        'Order ID',
        'Order Number',
        'Buyer',
        'Order Status',
        'Payment Status',
        'Courier',
        'Tracking Number',
        'Created At',
      ],
      ...orders.map((order) {
        return [
          order.id,
          order.orderNumber,
          order.shippingName ?? '',
          order.status,
          order.paymentStatus,
          order.shippingProvider ?? '',
          order.trackingNumber ?? '',
          order.createdAt.toIso8601String(),
        ];
      }),
    ];

    await _writeCsvReport(context, storeName, 'shipment-report', rows);
  }

  Future<void> _writeCsvReport(
    BuildContext context,
    String storeName,
    String reportName,
    List<List<String>> rows,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final directory = _exportDirectory();
      final filename =
          '${_safeFileName(storeName)}-$reportName-${_dateStamp()}.csv';
      final file = File('${directory.path}${Platform.pathSeparator}$filename');

      await directory.create(recursive: true);
      await file.writeAsString(_toCsv(rows));

      messenger.showSnackBar(
        SnackBar(content: Text('Export saved: ${file.path}')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $error')));
    }
  }

  Directory _exportDirectory() {
    final userProfile = Platform.environment['USERPROFILE'];
    if (Platform.isWindows && userProfile != null && userProfile.isNotEmpty) {
      return Directory('$userProfile${Platform.pathSeparator}Downloads');
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory('$home${Platform.pathSeparator}Downloads');
    }

    return Directory.systemTemp;
  }

  String _toCsv(List<List<String>> rows) {
    return rows
        .map((row) {
          return row.map(_escapeCsvValue).join(',');
        })
        .join('\n');
  }

  String _escapeCsvValue(String value) {
    final escaped = value.replaceAll('"', '""');

    if (escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('\r') ||
        escaped.contains('"')) {
      return '"$escaped"';
    }

    return escaped;
  }

  String _safeFileName(String value) {
    final sanitized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    return sanitized.isEmpty ? 'store' : sanitized;
  }

  String _dateStamp() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    return '${now.year}$month${day}_$hour$minute';
  }

  Widget _buildProductMetrics(List<ProductModel> products) {
    final published = products
        .where((product) => product.status == 'published')
        .length;
    final draft = products.where((product) => product.status == 'draft').length;
    final lowStock = products
        .where((product) => product.stock > 0 && product.stock <= 5)
        .length;
    final outOfStock = products.where((product) => product.stock == 0).length;

    return _buildMetricPanel(
      title: 'Ringkasan Produk',
      metrics: [
        _DashboardMetric(
          label: 'Total Produk',
          value: products.length.toString(),
          icon: Icons.inventory_2_outlined,
          color: Colors.blue,
        ),
        _DashboardMetric(
          label: 'Aktif / Tayang',
          value: published.toString(),
          icon: Icons.visibility_outlined,
          color: Colors.green,
        ),
        _DashboardMetric(
          label: 'Draf',
          value: draft.toString(),
          icon: Icons.edit_note,
          color: Colors.orange,
        ),
        _DashboardMetric(
          label: 'Stok Kritis / Habis',
          value: '${lowStock + outOfStock}',
          icon: Icons.warning_amber_outlined,
          color: lowStock + outOfStock > 0 ? Colors.red : Colors.green,
        ),
      ],
    );
  }

  Widget _buildOrderMetrics(List<OrderModel> orders) {
    final processing = orders
        .where(
          (order) =>
              order.status == 'processing' && order.paymentStatus == 'paid',
        )
        .length;
    final shipped = orders.where((order) => order.status == 'shipped').length;
    final completed = orders
        .where((order) => order.status == 'completed')
        .length;
    final pendingPayment = orders
        .where((order) => order.paymentStatus == 'pending')
        .length;

    return _buildMetricPanel(
      title: 'Status Pesanan',
      metrics: [
        _DashboardMetric(
          label: 'Siap Kirim',
          value: processing.toString(),
          icon: Icons.local_shipping_outlined,
          color: processing > 0 ? Colors.blue : Colors.grey,
        ),
        _DashboardMetric(
          label: 'Dikirim',
          value: shipped.toString(),
          icon: Icons.inventory_outlined,
          color: shipped > 0 ? Colors.deepPurple : Colors.grey,
        ),
        _DashboardMetric(
          label: 'Selesai',
          value: completed.toString(),
          icon: Icons.check_circle_outline,
          color: Colors.green,
        ),
        _DashboardMetric(
          label: 'Belum Bayar',
          value: pendingPayment.toString(),
          icon: Icons.payments_outlined,
          color: pendingPayment > 0 ? Colors.orange : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildFinancialReport(List<OrderModel> orders) {
    final paidOrders = orders
        .where(
          (order) =>
              order.paymentStatus == 'paid' &&
              order.status != 'cancelled' &&
              order.status != 'failed',
        )
        .toList();
    final completedOrders = orders
        .where(
          (order) =>
              order.paymentStatus == 'paid' && order.status == 'completed',
        )
        .toList();
    final pendingPaymentOrders = orders
        .where((order) => order.paymentStatus == 'pending')
        .toList();

    final paidRevenue = _sumOrderAmount(paidOrders);
    final completedRevenue = _sumOrderAmount(completedOrders);
    final pendingPaymentValue = _sumOrderAmount(pendingPaymentOrders);

    return _buildMetricPanel(
      title: 'Laporan Keuangan',
      metrics: [
        _DashboardMetric(
          label: 'Pendapatan Masuk',
          value: _compactRupiah(paidRevenue),
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.green,
          tooltip: CurrencyFormatter.format(paidRevenue),
        ),
        _DashboardMetric(
          label: 'Pesanan Selesai',
          value: _compactRupiah(completedRevenue),
          icon: Icons.verified_outlined,
          color: Colors.teal,
          tooltip: CurrencyFormatter.format(completedRevenue),
        ),
        _DashboardMetric(
          label: 'Menunggu Bayar',
          value: _compactRupiah(pendingPaymentValue),
          icon: Icons.schedule_outlined,
          color: pendingPaymentValue > 0 ? Colors.orange : Colors.grey,
          tooltip: CurrencyFormatter.format(pendingPaymentValue),
        ),
        _DashboardMetric(
          label: 'Transaksi Lunas',
          value: paidOrders.length.toString(),
          icon: Icons.receipt_long_outlined,
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildBuyerReport(List<OrderModel> orders) {
    final buyerOrderCounts = <String, int>{};

    for (final order in orders) {
      final buyerKey = order.userId ?? order.shippingName;

      if (buyerKey == null || buyerKey.isEmpty) {
        continue;
      }

      buyerOrderCounts[buyerKey] = (buyerOrderCounts[buyerKey] ?? 0) + 1;
    }

    final uniqueBuyers = buyerOrderCounts.length;
    final repeatBuyers = buyerOrderCounts.values
        .where((orderCount) => orderCount > 1)
        .length;
    final paidBuyerKeys = orders
        .where((order) => order.paymentStatus == 'paid')
        .map((order) => order.userId ?? order.shippingName)
        .whereType<String>()
        .where((buyerKey) => buyerKey.isNotEmpty)
        .toSet();

    return _buildMetricPanel(
      title: 'Laporan Pelanggan',
      metrics: [
        _DashboardMetric(
          label: 'Total Pembeli',
          value: uniqueBuyers.toString(),
          icon: Icons.people_alt_outlined,
          color: Colors.indigo,
        ),
        _DashboardMetric(
          label: 'Pembeli Lunas',
          value: paidBuyerKeys.length.toString(),
          icon: Icons.person_add_alt_1_outlined,
          color: Colors.green,
        ),
        _DashboardMetric(
          label: 'Pelanggan Setia',
          value: repeatBuyers.toString(),
          icon: Icons.repeat_outlined,
          color: repeatBuyers > 0 ? Colors.deepPurple : Colors.grey,
        ),
        _DashboardMetric(
          label: 'Total Transaksi',
          value: orders.length.toString(),
          icon: Icons.shopping_bag_outlined,
          color: Colors.blueGrey,
        ),
      ],
    );
  }

  Widget _buildShipmentReport(List<OrderModel> orders) {
    final readyToShip = orders
        .where(
          (order) =>
              order.status == 'processing' && order.paymentStatus == 'paid',
        )
        .length;
    final shipped = orders.where((order) => order.status == 'shipped').length;
    final completed = orders
        .where((order) => order.status == 'completed')
        .length;
    final withTracking = orders
        .where(
          (order) =>
              order.shippingProvider != null &&
              order.shippingProvider!.isNotEmpty &&
              order.trackingNumber != null &&
              order.trackingNumber!.isNotEmpty,
        )
        .length;

    return _buildMetricPanel(
      title: 'Laporan Pengiriman',
      metrics: [
        _DashboardMetric(
          label: 'Siap Kirim',
          value: readyToShip.toString(),
          icon: Icons.inventory_outlined,
          color: readyToShip > 0 ? Colors.orange : Colors.grey,
        ),
        _DashboardMetric(
          label: 'Dalam Perjalanan',
          value: shipped.toString(),
          icon: Icons.local_shipping_outlined,
          color: shipped > 0 ? Colors.blue : Colors.grey,
        ),
        _DashboardMetric(
          label: 'Terkirim',
          value: completed.toString(),
          icon: Icons.task_alt_outlined,
          color: Colors.green,
        ),
        _DashboardMetric(
          label: 'Ada Nomor Resi',
          value: withTracking.toString(),
          icon: Icons.confirmation_number_outlined,
          color: withTracking > 0 ? Colors.deepPurple : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildGoodsReport(List<ProductModel> products) {
    final totalStock = products.fold<int>(
      0,
      (sum, product) => sum + product.stock,
    );
    final inventoryValue = products.fold<int>(
      0,
      (sum, product) => sum + (product.price * product.stock),
    );
    final activeProducts = products
        .where((product) => product.status == 'published')
        .length;
    final unavailableProducts = products
        .where((product) => product.stock == 0 || product.status != 'published')
        .length;

    return _buildMetricPanel(
      title: 'Laporan Data Barang',
      metrics: [
        _DashboardMetric(
          label: 'Total Stok',
          value: totalStock.toString(),
          icon: Icons.warehouse_outlined,
          color: Colors.teal,
        ),
        _DashboardMetric(
          label: 'Nilai Aset Barang',
          value: _compactRupiah(inventoryValue),
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.indigo,
        ),
        _DashboardMetric(
          label: 'Siap Dijual',
          value: activeProducts.toString(),
          icon: Icons.check_circle_outline,
          color: Colors.green,
        ),
        _DashboardMetric(
          label: 'Stok Habis / Draf',
          value: unavailableProducts.toString(),
          icon: Icons.block_outlined,
          color: unavailableProducts > 0 ? Colors.red : Colors.grey,
        ),
      ],
    );
  }

  String _compactRupiah(int value) {
    if (value >= 1000000) {
      final compact = value / 1000000;
      return 'Rp ${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}Jt';
    }

    if (value >= 1000) {
      final compact = value / 1000;
      return 'Rp ${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}Rb';
    }

    return 'Rp $value';
  }

  int _sumOrderAmount(List<OrderModel> orders) {
    var total = 0;

    for (final order in orders) {
      total += order.totalAmount;
    }

    return total;
  }

  Widget _buildMetricPanel({
    required String title,
    required List<_DashboardMetric> metrics,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth < 520
                  ? (constraints.maxWidth - 12) / 2
                  : (constraints.maxWidth - 36) / 4;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: metrics.map((metric) {
                  return SizedBox(
                    width: itemWidth,
                    child: _buildMetricTile(metric),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(_DashboardMetric metric) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: metric.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: metric.color),
          const SizedBox(height: 10),
          Tooltip(
            message: metric.tooltip ?? metric.value,
            child: Text(
              metric.value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Text(metric.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildLowStockAlerts(
    BuildContext context,
    List<ProductModel> products,
  ) {
    final alertProducts =
        products.where((product) => product.stock <= 5).toList()
          ..sort((a, b) => a.stock.compareTo(b.stock));

    if (alertProducts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Stok seluruh produk aman (di atas 5 pcs)',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Peringatan Stok Menipis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...alertProducts.take(5).map((product) {
            final isOut = product.stock == 0;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isOut
                    ? Icons.remove_shopping_cart_outlined
                    : Icons.warning_amber_outlined,
                color: isOut ? Colors.red : Colors.orange,
              ),
              title: Text(product.name),
              subtitle: Text(
                isOut ? 'Stok Habis (0 pcs)' : 'Sisa stok: ${product.stock} pcs',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push('/seller/products/${product.id}/edit');
              },
            );
          }),
          if (alertProducts.length > 5) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                context.push('/seller/products');
              },
              child: Text(
                'Lihat ${alertProducts.length - 5} produk menipis lainnya',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricError(Object error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(error.toString()),
    );
  }

  Widget _buildMetricItem({
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

Widget _buildStoreSummary(StoreModel store, WidgetRef ref) {
  final reviewsAsync = ref.watch(storeReviewsProvider(store.id));

  return Container(
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
            Expanded(
              child: Text(
                store.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildStatusBadge(store.status),
          ],
        ),

        // Store Rating Summary
        reviewsAsync.when(
          data: (reviews) {
            if (reviews.isEmpty) return const SizedBox.shrink();
            final approvedReviews = reviews
                .where((r) => r['is_approved'] == true)
                .toList();
            if (approvedReviews.isEmpty) return const SizedBox.shrink();

            final totalRating = approvedReviews.fold<double>(
              0,
              (sum, r) => sum + (r['rating'] as num),
            );
            final avgRating = totalRating / approvedReviews.length;

            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${avgRating.toStringAsFixed(1)} / 5.0',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${approvedReviews.length} ulasan)',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),

        if (store.phone != null) ...[
          const SizedBox(height: 16),
          Text('Telepon: ${store.phone}'),
        ],

        if (store.address != null) ...[
          const SizedBox(height: 8),
          Text('Alamat: ${store.address}'),
        ],

        if (store.description != null) ...[
          const SizedBox(height: 16),
          Text(store.description!),
        ],
      ],
    ),
  );
}

Widget _buildStatusBadge(String status) {
  final isActive = status == 'active';
  final color = isActive ? Colors.green : Colors.orange;
  final label = isActive ? 'Toko Aktif' : 'Menunggu / Draf';

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

Widget _buildActionTile({
  required IconData icon,
  required String title,
  required String subtitle,
  VoidCallback? onTap,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,

    child: Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          Icon(icon),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(subtitle),
              ],
            ),
          ),

          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );
}

class _DashboardMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? tooltip;

  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.tooltip,
  });
}

class _BuyerReportRow {
  final String buyerKey;
  final String buyerName;
  int orderCount = 0;
  int paidOrderCount = 0;
  int totalSpend = 0;
  DateTime? lastOrderAt;

  _BuyerReportRow({required this.buyerKey, required this.buyerName});
}
