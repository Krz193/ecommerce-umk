import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';

import 'package:mobile/features/order/providers/orders_provider.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage>
    with WidgetsBindingObserver {
  Timer? refreshTimer;
  DateTime? lastResumeRefresh;

  bool hasPendingOrders(List<dynamic> orders) {
    return orders.any((order) => order.paymentStatus == 'pending');
  }

  void startPolling() {
    refreshTimer?.cancel();

    refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      debugPrint('refreshing orders page');

      ref.invalidate(ordersProvider);
    });
  }

  void stopPolling() {
    refreshTimer?.cancel();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() {
      ref.invalidate(ordersProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    stopPolling();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final now = DateTime.now();

      if (lastResumeRefresh != null &&
          now.difference(lastResumeRefresh!).inSeconds < 3) {
        return;
      }

      lastResumeRefresh = now;

      debugPrint('app resumed -> refresh orders');

      ref.invalidate(ordersProvider);
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;

      case 'pending':
        return Colors.orange;

      case 'expired':
        return Colors.red;

      case 'failed':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  String notificationText(dynamic order) {
    if (order.paymentStatus == 'pending') {
      return 'Selesaikan pembayaran untuk pesanan ${order.orderNumber}';
    }

    if (order.paymentStatus == 'paid' && order.status == 'processing') {
      return 'Pesanan ${order.orderNumber} sedang disiapkan oleh penjual';
    }

    if (order.status == 'shipped') {
      return 'Pesanan ${order.orderNumber} sedang dalam pengiriman';
    }

    if (order.status == 'completed') {
      return 'Pesanan ${order.orderNumber} telah selesai';
    }

    if (order.paymentStatus == 'expired' || order.paymentStatus == 'failed') {
      return 'Pembayaran pesanan ${order.orderNumber} tidak selesai';
    }

    return 'Status pesanan ${order.orderNumber} diperbarui';
  }

  String displayStatus(dynamic order) {
    if (order.paymentStatus == 'pending') {
      return 'Menunggu Pembayaran';
    }

    if (order.paymentStatus == 'paid' && order.status == 'processing') {
      return 'Diproses Penjual';
    }

    if (order.status == 'shipped') {
      return 'Dikirim';
    }

    if (order.status == 'completed') {
      return 'Selesai';
    }

    if (order.paymentStatus == 'expired') {
      return 'Pembayaran Kadaluarsa';
    }

    if (order.paymentStatus == 'failed') {
      return 'Pembayaran Gagal';
    }

    return order.status;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan Saya')),

      body: ordersAsync.when(
        data: (orders) {
          if (hasPendingOrders(orders)) {
            startPolling();
          } else {
            stopPolling();
          }

          if (orders.isEmpty) {
            return const Center(child: Text('Belum ada pesanan'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(ordersProvider);
            },

            child: ListView.separated(
              padding: const EdgeInsets.all(24),

              itemCount: orders.length + 1,

              separatorBuilder: (context, index) => const SizedBox(height: 16),

              itemBuilder: (context, index) {
                if (index == 0) {
                  return buildStatusNotice(orders.first);
                }

                final order = orders[index - 1];

                return GestureDetector(
                  onTap: () {
                    context.push('/orders/${order.id}');
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
                        Text(
                          order.orderNumber,

                          style: const TextStyle(
                            fontSize: 16,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(CurrencyFormatter.format(order.totalAmount)),

                        const SizedBox(height: 8),

                        Text(
                          DateFormatter.formatDateTime(
                            order.createdAt.toString(),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),

                          decoration: BoxDecoration(
                            color: getStatusColor(
                              order.paymentStatus,
                            ).withValues(alpha: 0.15),

                            borderRadius: BorderRadius.circular(999),
                          ),

                          child: Text(
                            displayStatus(order),

                            style: TextStyle(
                              color: getStatusColor(order.paymentStatus),

                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
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
      ),
    );
  }

  Widget buildStatusNotice(dynamic order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_none, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notificationText(order),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
