import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/order/models/order_model.dart';
import 'package:mobile/features/order/providers/seller_order_provider.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerOrdersPage extends ConsumerStatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  ConsumerState<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends ConsumerState<SellerOrdersPage> {
  final searchController = TextEditingController();

  String searchQuery = '';

  final tabs = const [
    _OrderStatusTab(label: 'All', status: null),
    _OrderStatusTab(label: 'Processing', status: 'processing'),
    _OrderStatusTab(label: 'Shipped', status: 'shipped'),
    _OrderStatusTab(label: 'Completed', status: 'completed'),
  ];

  @override
  void dispose() {
    searchController.dispose();

    super.dispose();
  }

  void updateSearch(String value) {
    setState(() {
      searchQuery = value.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(managedStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Store Orders')),
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
                      'Create a store before managing orders',
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

          final ordersAsync = ref.watch(sellerOrdersProvider(store.id));

          return ordersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return const Center(child: Text('No store orders yet'));
              }

              return DefaultTabController(
                length: tabs.length,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        children: [
                          buildSellerNotice(orders),
                          const SizedBox(height: 12),
                          TextField(
                            controller: searchController,
                            onChanged: updateSearch,
                            textInputAction: TextInputAction.search,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              labelText: 'Search order number',
                            ),
                          ),
                        ],
                      ),
                    ),
                    TabBar(
                      isScrollable: true,
                      tabs: tabs.map((tab) {
                        return Tab(
                          text: '${tab.label} (${countOrders(orders, tab)})',
                        );
                      }).toList(),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: tabs.map((tab) {
                          final filteredOrders = filterOrders(orders, tab);

                          return buildOrderList(
                            storeId: store.id,
                            orders: filteredOrders,
                          );
                        }).toList(),
                      ),
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

  int countOrders(List<OrderModel> orders, _OrderStatusTab tab) {
    if (tab.status == null) {
      return orders.length;
    }

    return orders.where((order) => order.status == tab.status).length;
  }

  List<OrderModel> filterOrders(List<OrderModel> orders, _OrderStatusTab tab) {
    return orders.where((order) {
      final matchesStatus = tab.status == null || order.status == tab.status;

      final matchesQuery =
          searchQuery.isEmpty ||
          order.orderNumber.toLowerCase().contains(searchQuery);

      return matchesStatus && matchesQuery;
    }).toList();
  }

  Widget buildOrderList({
    required String storeId,
    required List<OrderModel> orders,
  }) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sellerOrdersProvider(storeId));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 160),
            Center(child: Text('No matching orders')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sellerOrdersProvider(storeId));
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return buildOrderCard(context, orders[index]);
        },
      ),
    );
  }

  Widget buildOrderCard(BuildContext context, OrderModel order) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        context.push('/seller/orders/${order.id}');
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
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 12),
            Text(CurrencyFormatter.format(order.totalAmount)),
            const SizedBox(height: 8),
            Text(DateFormatter.formatDateTime(order.createdAt.toString())),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildStatusBadge(order.status),
                buildPaymentBadge(order.paymentStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSellerNotice(List<OrderModel> orders) {
    final readyToShip = orders
        .where(
          (order) =>
              order.status == 'processing' && order.paymentStatus == 'paid',
        )
        .length;

    final shipped = orders.where((order) => order.status == 'shipped').length;

    final text = readyToShip > 0
        ? '$readyToShip paid order(s) ready to ship'
        : shipped > 0
        ? '$shipped shipped order(s) waiting for buyer confirmation'
        : 'No urgent seller actions';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatusBadge(String status) {
    final color = switch (status) {
      'processing' => Colors.blue,
      'shipped' => Colors.deepPurple,
      'completed' => Colors.green,
      'cancelled' => Colors.red,
      _ => Colors.grey,
    };

    return buildBadge(status, color);
  }

  Widget buildPaymentBadge(String status) {
    final color = switch (status) {
      'paid' => Colors.green,
      'pending' => Colors.orange,
      'expired' => Colors.red,
      'failed' => Colors.red,
      _ => Colors.grey,
    };

    return buildBadge(status, color);
  }

  Widget buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _OrderStatusTab {
  final String label;
  final String? status;

  const _OrderStatusTab({required this.label, required this.status});
}
