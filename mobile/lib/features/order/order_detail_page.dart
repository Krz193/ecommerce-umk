import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';

import 'package:mobile/features/order/providers/order_detail_provider.dart';

import 'package:go_router/go_router.dart';

class OrderDetailPage extends ConsumerWidget {
  final String orderId;

  const OrderDetailPage({
    super.key,
    required this.orderId,
  });

  Color getStatusColor(
    String status,
  ) {
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

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {

    final orderAsync =
        ref.watch(
      orderDetailProvider(orderId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order Detail',
        ),
      ),

      body: orderAsync.when(
        data: (order) {

          return ListView(
            padding: const EdgeInsets.all(24),

            children: [

              Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      order.orderNumber,

                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Text(
                      CurrencyFormatter.format(
                        order.totalAmount,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      DateFormatter
                          .formatDateTime(
                        order.createdAt
                            .toString(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: getStatusColor(
                          order.paymentStatus,
                        ).withValues(
                          alpha: 0.15,
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          999,
                        ),
                      ),

                      child: Text(
                        order.paymentStatus,

                        style: TextStyle(
                          color: getStatusColor(
                            order.paymentStatus,
                          ),

                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    if (
                      order.paymentStatus == 'pending' &&
                      order.payment != null
                    ) ...[

                      const SizedBox(
                        height: 16,
                      ),

                      SizedBox(
                        width: double.infinity,

                        child: ElevatedButton(
                          onPressed: () {

                            context.push(
                              '/payment',

                              extra: {
                                'order': {
                                  'id': order.id,

                                  'order_number':
                                      order.orderNumber,

                                  'total_amount':
                                      order.totalAmount,
                                },

                                'payment': {
                                  'id':
                                      order.payment!.id,

                                  'status':
                                      order.payment!.status,

                                  'expired_at':
                                      order.payment!.expiredAt,
                                },

                                'midtrans':
                                    order.payment!.rawResponse,
                              },
                            );
                          },

                          child: const Text(
                            'Continue Payment',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              const Text(
                'Items',

                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              ...order.items.map(
                (item) {

                  return Container(
                    margin:
                        const EdgeInsets.only(
                      bottom: 16,
                    ),

                    padding:
                        const EdgeInsets.all(
                      16,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,

                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),

                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [

                        Text(
                          item.productName,

                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        Text(
                          CurrencyFormatter
                              .format(
                            item.productPrice,
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        Text(
                          'Quantity: ${item.quantity}',
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        Text(
                          'Subtotal: ${CurrencyFormatter.format(item.subtotal)}',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },

        error: (
          error,
          stackTrace,
        ) {

          return Center(
            child: Text(
              error.toString(),
            ),
          );
        },

        loading: () {

          return const Center(
            child:
                CircularProgressIndicator(),
          );
        },
      ),
    );
  }
}