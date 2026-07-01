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

class SellerStoreDashboardPage extends ConsumerWidget {
  const SellerStoreDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Store'),
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
                      'No store yet',
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
                      child: const Text('Create Store'),
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
                _buildStoreSummary(store),

                const SizedBox(height: 16),

                _buildActionTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Products',
                  subtitle: 'Manage store products',
                  onTap: () {
                    context.push('/seller/products');
                  },
                ),

                const SizedBox(height: 12),

                _buildActionTile(
                  icon: Icons.analytics_outlined,
                  title: 'Reports',
                  subtitle:
                      'View store metrics, stock alerts, and sales reports',
                  onTap: () {
                    context.push('/seller/reports');
                  },
                ),

                const SizedBox(height: 12),

                _buildActionTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Orders',
                  subtitle: 'Manage incoming orders',
                  onTap: () {
                    context.push('/seller/orders');
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
        title: const Text('Store Reports'),
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
            return const Center(child: Text('No store yet'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sellerProductsProvider(store.id));
              ref.invalidate(sellerOrdersProvider(store.id));
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
            'Operational metrics, goods report, financial report, buyer report, shipment report, and stock alerts.',
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
            'Export CSV',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Download detailed report files that can be opened in Excel.',
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
                label: const Text('Goods'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _exportFinancialReport(context, storeName, orders);
                },
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Financial'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _exportBuyerReport(context, storeName, orders);
                },
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text('Buyer'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _exportShipmentReport(context, storeName, orders);
                },
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Shipment'),
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
      title: 'Product Metrics',
      metrics: [
        _DashboardMetric(
          label: 'Total',
          value: products.length.toString(),
          icon: Icons.inventory_2_outlined,
          color: Colors.blue,
        ),
        _DashboardMetric(
          label: 'Published',
          value: published.toString(),
          icon: Icons.visibility_outlined,
          color: Colors.green,
        ),
        _DashboardMetric(
          label: 'Draft',
          value: draft.toString(),
          icon: Icons.edit_note,
          color: Colors.orange,
        ),
        _DashboardMetric(
          label: 'Low/Out',
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
      title: 'Order Metrics',
      metrics: [
        _DashboardMetric(
          label: 'Ready Ship',
          value: processing.toString(),
          icon: Icons.local_shipping_outlined,
          color: processing > 0 ? Colors.blue : Colors.grey,
        ),
        _DashboardMetric(
          label: 'Shipped',
          value: shipped.toString(),
          icon: Icons.inventory_outlined,
          color: shipped > 0 ? Colors.deepPurple : Colors.grey,
        ),
        _DashboardMetric(
          label: 'Completed',
          value: completed.toString(),
          icon: Icons.check_circle_outline,
          color: Colors.green,
        ),
        _DashboardMetric(
          label: 'Pending Pay',
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
      title: 'Financial Report',
      metrics: [
        _DashboardMetric(
          label: 'Paid Revenue',
          value: _compactRupiah(paidRevenue),
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.green,
          tooltip: CurrencyFormatter.format(paidRevenue),
        ),
        _DashboardMetric(
          label: 'Completed',
          value: _compactRupiah(completedRevenue),
          icon: Icons.verified_outlined,
          color: Colors.teal,
          tooltip: CurrencyFormatter.format(completedRevenue),
        ),
        _DashboardMetric(
          label: 'Pending Pay',
          value: _compactRupiah(pendingPaymentValue),
          icon: Icons.schedule_outlined,
          color: pendingPaymentValue > 0 ? Colors.orange : Colors.grey,
          tooltip: CurrencyFormatter.format(pendingPaymentValue),
        ),
        _DashboardMetric(
          label: 'Paid Orders',
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
      title: 'Buyer Report',
      metrics: [
        _DashboardMetric(
          label: 'Unique Buyers',
          value: uniqueBuyers.toString(),
          icon: Icons.people_alt_outlined,
          color: Colors.indigo,
        ),
        _DashboardMetric(
          label: 'Paid Buyers',
          value: paidBuyerKeys.length.toString(),
          icon: Icons.person_add_alt_1_outlined,
          color: Colors.green,
        ),
        _DashboardMetric(
          label: 'Repeat Buyers',
          value: repeatBuyers.toString(),
          icon: Icons.repeat_outlined,
          color: repeatBuyers > 0 ? Colors.deepPurple : Colors.grey,
        ),
        _DashboardMetric(
          label: 'Buyer Orders',
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
      title: 'Shipment Report',
      metrics: [
        _DashboardMetric(
          label: 'Ready Ship',
          value: readyToShip.toString(),
          icon: Icons.inventory_outlined,
          color: readyToShip > 0 ? Colors.orange : Colors.grey,
        ),
        _DashboardMetric(
          label: 'In Transit',
          value: shipped.toString(),
          icon: Icons.local_shipping_outlined,
          color: shipped > 0 ? Colors.blue : Colors.grey,
        ),
        _DashboardMetric(
          label: 'Delivered',
          value: completed.toString(),
          icon: Icons.task_alt_outlined,
          color: Colors.green,
        ),
        _DashboardMetric(
          label: 'With Tracking',
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
      title: 'Goods Report',
      metrics: [
        _DashboardMetric(
          label: 'Total Stock',
          value: totalStock.toString(),
          icon: Icons.warehouse_outlined,
          color: Colors.teal,
        ),
        _DashboardMetric(
          label: 'Stock Value',
          value: _compactRupiah(inventoryValue),
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.indigo,
        ),
        _DashboardMetric(
          label: 'Active',
          value: activeProducts.toString(),
          icon: Icons.check_circle_outline,
          color: Colors.green,
        ),
        _DashboardMetric(
          label: 'Unavailable',
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
      return 'Rp ${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}M';
    }

    if (value >= 1000) {
      final compact = value / 1000;
      return 'Rp ${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}K';
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
            Expanded(child: Text('No low stock alerts')),
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
            'Low Stock Alerts',
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
                isOut ? 'Out of stock' : 'Stock: ${product.stock}',
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
              child: Text('View ${alertProducts.length - 5} more alert(s)'),
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
}

Widget _buildStoreSummary(StoreModel store) {
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

        if (store.phone != null) ...[
          const SizedBox(height: 16),
          Text('Phone: ${store.phone}'),
        ],

        if (store.address != null) ...[
          const SizedBox(height: 8),
          Text('Address: ${store.address}'),
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
  final color = status == 'active' ? Colors.green : Colors.orange;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),

    child: Text(
      status,
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
