import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
              ref.invalidate(sellerProductsProvider(store.id));
              ref.invalidate(sellerOrdersProvider(store.id));
            },

            child: ListView(
              padding: const EdgeInsets.all(16),

              children: [
                _buildStoreSummary(store),

                const SizedBox(height: 16),

                _buildDashboardMetrics(context, ref, store.id),

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

  Widget _buildDashboardMetrics(
    BuildContext context,
    WidgetRef ref,
    String storeId,
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
                _buildProductMetrics(products),
                const SizedBox(height: 12),
                _buildOrderMetrics(orders),
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
          Text(
            metric.value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
}

class _DashboardMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
