import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';

import 'package:mobile/features/order/providers/orders_provider.dart';

class OrdersPage
    extends ConsumerStatefulWidget {

  const OrdersPage({
    super.key,
  });

  @override
  ConsumerState<OrdersPage>
  createState() =>
      _OrdersPageState();
}

class _OrdersPageState
    extends ConsumerState<OrdersPage> {

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.invalidate(
        ordersProvider,
      );
    });
  }

  Color getStatusColor(
    String status,
  ){
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
  ) {

    final ordersAsync =
        ref.watch(
      ordersProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Orders',
        ),
      ),

      body: ordersAsync.when(
        data: (orders) {

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No orders yet',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                ordersProvider,
              );
            },

            child: ListView.separated(
              padding:
                  const EdgeInsets.all(
                24,
              ),

              itemCount: orders.length,

              separatorBuilder:
                  (
                    context,
                    index,
                  ) =>
                      const SizedBox(
                height: 16,
              ),

              itemBuilder:
                  (
                    context,
                    index,
                  ) {

                final order =
                    orders[index];

                return GestureDetector(
                  onTap: () {

                    context.push(
                      '/orders/${order.id}',
                    );
                  },

                  child: Container(
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
                          order.orderNumber,

                          style:
                              const TextStyle(
                            fontSize: 16,

                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Text(
                          CurrencyFormatter
                              .format(
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

                          decoration:
                              BoxDecoration(
                            color:
                                getStatusColor(
                              order
                                  .paymentStatus,
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
                              color:
                                  getStatusColor(
                                order
                                    .paymentStatus,
                              ),

                              fontWeight:
                                  FontWeight
                                      .bold,
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