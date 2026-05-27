import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';

import 'package:mobile/features/order/providers/order_detail_provider.dart';

import 'package:go_router/go_router.dart';

class OrderDetailPage extends ConsumerWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

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

  List<Map<String, dynamic>> buildTimeline(
  dynamic order,
) {

  final timeline =
      <Map<String, dynamic>>[];

  timeline.add({
    'title': 'Order Created',
    'date': order.createdAt,
    'completed': true,
  });

  if (
    order.paymentStatus == 'pending'
  ) {

    timeline.add({
      'title': 'Waiting Payment',
      'date': null,
      'completed': false,
    });
  }

  if (
    order.paymentStatus == 'paid'
  ) {

    timeline.add({
      'title': 'Payment Success',
      'date': null,
      'completed': true,
    });

    timeline.add({
      'title': 'Order Confirmed',
      'date': null,
      'completed': false,
    });

    timeline.add({
      'title': 'Shipped',
      'date': null,
      'completed': false,
    });

    timeline.add({
      'title': 'Completed',
      'date': null,
      'completed': false,
    });
  }

  if (
    order.paymentStatus == 'expired'
  ) {

    timeline.add({
      'title': 'Payment Expired',
      'date': order.payment?.expiredAt,
      'completed': true,
    });
  }

  return timeline;
}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order Detail')),

      body: orderAsync.when(
        data: (order) {
          final timeline = buildTimeline(order);

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
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const SizedBox(height: 24),

const Text(
  'Timeline',

  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 16),

Container(
  padding: const EdgeInsets.all(16),

  decoration: BoxDecoration(
    color: Colors.white,

    borderRadius:
        BorderRadius.circular(16),
  ),

  child: Column(
    children:
        timeline.asMap().entries.map(
      (entry) {

        final index =
            entry.key;

        final item =
            entry.value;

        final isLast =
            index ==
            timeline.length - 1;

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Column(
              children: [

                Container(
                  width: 14,
                  height: 14,

                  decoration:
                      BoxDecoration(
                    color:
                        item['completed']
                            ? Colors.black
                            : Colors.grey,

                    shape:
                        BoxShape.circle,
                  ),
                ),

                if (!isLast)
                  Container(
                    width: 2,
                    height: 64,

                    color:
                        Colors.grey.shade300,
                  ),
              ],
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 24,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [

                    Text(
                      item['title'],

                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    if (
                      item['date'] != null
                    ) ...[

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        DateFormatter
                            .formatDateTime(
                          item['date']
                              .toString(),
                        ),

                        style:
                            TextStyle(
                          color:
                              Colors
                                  .grey
                                  .shade600,

                          fontSize:
                              12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ).toList(),
  ),
),

              const Text(
                'Items',

                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              ...order.items.map((item) {
                debugPrint(item.productThumbnail);

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
