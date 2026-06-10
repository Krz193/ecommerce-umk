import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';

import 'package:mobile/features/order/providers/order_detail_provider.dart';
import 'package:mobile/features/order/providers/order_status_provider.dart';
import 'package:mobile/features/order/providers/orders_provider.dart';

import 'package:go_router/go_router.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage>
    with WidgetsBindingObserver {
  Timer? refreshTimer;
  DateTime? lastResumeRefresh;
  bool isUpdating = false;

  Future<void> confirmReceived() async {
    setState(() {
      isUpdating = true;
    });

    try {
      final service = ref.read(orderStatusServiceProvider);

      await service.confirmReceived(orderId: widget.orderId);

      if (!mounted) {
        return;
      }

      ref.invalidate(ordersProvider);
      ref.invalidate(orderDetailProvider(widget.orderId));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order completed')));
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
          isUpdating = false;
        });
      }
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

  List<Map<String, dynamic>> buildTimeline(dynamic order) {
    final timeline = <Map<String, dynamic>>[];

    timeline.add({
      'title': 'Order Created',
      'date': order.createdAt,
      'completed': true,
    });

    if (order.paymentStatus == 'pending') {
      timeline.add({
        'title': 'Waiting Payment',
        'date': null,
        'completed': false,
      });
    }

    if (order.paymentStatus == 'paid') {
      timeline.add({
        'title': 'Payment Success',
        'date': order.paidAt,
        'completed': true,
      });

      timeline.add({
        'title': 'Processing',
        'date': order.paidAt,
        'completed': [
          'processing',
          'shipped',
          'completed',
        ].contains(order.status),
      });

      timeline.add({
        'title': 'Shipped',
        'date': order.shippedAt,
        'completed': ['shipped', 'completed'].contains(order.status),
      });

      timeline.add({
        'title': 'Completed',
        'date': order.completedAt,
        'completed': order.status == 'completed',
      });
    }

    if (order.paymentStatus == 'expired') {
      timeline.add({
        'title': 'Payment Expired',
        'date': order.payment?.expiredAt,
        'completed': true,
      });
    }

    return timeline;
  }

  bool isFinalStatus(String status) {
    return status == 'paid' || status == 'expired' || status == 'failed';
  }

  void startPolling() {
    refreshTimer?.cancel();

    refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      debugPrint('refreshing order detail');

      ref.invalidate(orderDetailProvider(widget.orderId));
    });
  }

  void stopPolling() {
    refreshTimer?.cancel();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    startPolling();
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

      debugPrint('app resumed -> refresh order detail');

      ref.invalidate(orderDetailProvider(widget.orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order Detail')),

      body: orderAsync.when(
        data: (order) {
          final timeline = buildTimeline(order);

          if (isFinalStatus(order.paymentStatus)) {
            stopPolling();
          }

          return ListView(
            padding: const EdgeInsets.all(24),

            children: [
              Container(
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(CurrencyFormatter.format(order.totalAmount)),

                    const SizedBox(height: 8),

                    Text(
                      DateFormatter.formatDateTime(order.createdAt.toString()),
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
                        order.paymentStatus,

                        style: TextStyle(
                          color: getStatusColor(order.paymentStatus),

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    if (order.paymentStatus == 'pending' &&
                        order.payment != null) ...[
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,

                        child: ElevatedButton(
                          onPressed: () {
                            context.push(
                              '/payment',

                              extra: {
                                'order': {
                                  'id': order.id,

                                  'order_number': order.orderNumber,

                                  'total_amount': order.totalAmount,
                                },

                                'payment': {
                                  'id': order.payment!.id,

                                  'status': order.payment!.status,

                                  'expired_at': order.payment!.expiredAt,
                                },

                                'midtrans': order.payment!.rawResponse,
                              },
                            );
                          },

                          child: const Text('Continue Payment'),
                        ),
                      ),
                    ],

                    if (order.shippingProvider != null ||
                        order.trackingNumber != null) ...[
                      const SizedBox(height: 16),
                      Text('Courier: ${order.shippingProvider ?? '-'}'),
                      const SizedBox(height: 8),
                      Text('Tracking Number: ${order.trackingNumber ?? '-'}'),
                    ],

                    if (order.status == 'shipped') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isUpdating ? null : confirmReceived,
                          child: isUpdating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Confirm Received'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const SizedBox(height: 24),

              const Text(
                'Timeline',

                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(16),
                ),

                child: Column(
                  children: timeline.asMap().entries.map((entry) {
                    final index = entry.key;

                    final item = entry.value;

                    final isLast = index == timeline.length - 1;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Column(
                          children: [
                            Container(
                              width: 14,
                              height: 14,

                              decoration: BoxDecoration(
                                color: item['completed']
                                    ? Colors.black
                                    : Colors.grey,

                                shape: BoxShape.circle,
                              ),
                            ),

                            if (!isLast)
                              Container(
                                width: 2,
                                height: 64,

                                color: Colors.grey.shade300,
                              ),
                          ],
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),

                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  item['title'],

                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                if (item['date'] != null) ...[
                                  const SizedBox(height: 4),

                                  Text(
                                    DateFormatter.formatDateTime(
                                      item['date'].toString(),
                                    ),

                                    style: TextStyle(
                                      color: Colors.grey.shade600,

                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const Text(
                'Items',

                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              ...order.items.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius: BorderRadius.circular(16),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      if (item.productThumbnail != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),

                          child: Image.network(
                            item.productThumbnail!,

                            height: 160,
                            width: double.infinity,

                            fit: BoxFit.cover,
                          ),
                        ),

                      if (item.productThumbnail != null)
                        const SizedBox(height: 12),

                      Text(
                        item.productName,

                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 8),

                      Text(CurrencyFormatter.format(item.productPrice)),

                      const SizedBox(height: 8),

                      Text('Quantity: ${item.quantity}'),

                      const SizedBox(height: 8),

                      Text(
                        'Subtotal: ${CurrencyFormatter.format(item.subtotal)}',
                      ),
                    ],
                  ),
                );
              }),
            ],
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
