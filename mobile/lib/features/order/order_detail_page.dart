import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';

import 'package:mobile/features/order/models/order_detail_model.dart';
import 'package:mobile/features/order/providers/order_detail_provider.dart';
import 'package:mobile/features/order/providers/refund_request_provider.dart';
import 'package:mobile/features/order/providers/order_status_provider.dart';
import 'package:mobile/features/order/providers/orders_provider.dart';
import 'package:mobile/features/order/widgets/refund_request_dialog.dart';
import 'package:mobile/features/product/providers/product_review_providers.dart';
import 'package:mobile/features/product/widgets/product_review_dialog.dart';

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
  bool isSubmittingRequest = false;

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

  Future<void> showRefundRequestDialog(String orderId) async {
    final result = await showDialog<RefundRequestDialogResult>(
      context: context,
      builder: (context) {
        return const RefundRequestDialog();
      },
    );

    if (result == null) {
      return;
    }

    await submitRefundRequest(
      orderId: orderId,
      requestType: result.requestType,
      reason: result.reason,
    );
  }

  Future<void> submitRefundRequest({
    required String orderId,
    required String requestType,
    required String reason,
  }) async {
    setState(() {
      isSubmittingRequest = true;
    });

    try {
      final service = ref.read(refundRequestServiceProvider);

      await service.createRequest(
        orderId: orderId,
        requestType: requestType,
        requesterRole: 'buyer',
        reason: reason,
      );

      ref.invalidate(refundRequestsProvider(orderId));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request submitted')));
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
          isSubmittingRequest = false;
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

  String displayStatus(OrderDetailModel order) {
    if (order.paymentStatus == 'pending') {
      return 'Waiting payment';
    }

    if (order.paymentStatus == 'paid' && order.status == 'processing') {
      return 'Processing';
    }

    if (order.status == 'shipped') {
      return 'Shipped';
    }

    if (order.status == 'completed') {
      return 'Completed';
    }

    if (order.paymentStatus == 'expired') {
      return 'Payment expired';
    }

    if (order.paymentStatus == 'failed') {
      return 'Payment failed';
    }

    return order.status;
  }

  String orderNotice(OrderDetailModel order) {
    if (order.paymentStatus == 'pending') {
      return 'Payment is still pending. Complete payment before the order can be processed.';
    }

    if (order.paymentStatus == 'paid' && order.status == 'processing') {
      return 'Payment received. The seller can now prepare this order.';
    }

    if (order.status == 'shipped') {
      return 'Order has been shipped. Confirm receipt after the package arrives.';
    }

    if (order.status == 'completed') {
      return 'Order completed.';
    }

    if (order.paymentStatus == 'expired' || order.paymentStatus == 'failed') {
      return 'Payment was not completed for this order.';
    }

    return 'Order status updated.';
  }

  List<Map<String, dynamic>> buildTimeline(OrderDetailModel order) {
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

    if (order.paymentStatus == 'failed') {
      timeline.add({
        'title': 'Payment Failed',
        'date': null,
        'completed': true,
      });
    }

    return timeline;
  }

  bool shouldStopPolling(OrderDetailModel order) {
    return order.status == 'completed' ||
        order.status == 'cancelled' ||
        order.paymentStatus == 'expired' ||
        order.paymentStatus == 'failed';
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

          if (shouldStopPolling(order)) {
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayStatus(order),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(Icons.notifications_none),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(orderNotice(order)),

                    const SizedBox(height: 16),

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
                        displayStatus(order),

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

                    const SizedBox(height: 16),
                    buildShipmentProgress(order),

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

              buildReceipt(order),

              const SizedBox(height: 24),

              buildRefundRequestSection(order),

              const SizedBox(height: 24),

              const Text(
                'Shipping Address',

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
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      order.shippingName,

                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    Text(order.shippingPhone),

                    const SizedBox(height: 8),

                    Text(order.shippingAddress),
                  ],
                ),
              ),

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
                      _OrderItemReviewButton(
                        orderId: order.id,
                        productId: item.productId,
                        isDeliveredOrCompleted:
                            order.status == 'delivered' ||
                            order.status == 'completed',
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

  Widget buildRefundRequestSection(OrderDetailModel order) {
    final requestsAsync = ref.watch(refundRequestsProvider(order.id));
    final canRequest =
        order.status != 'cancelled' &&
        ['paid', 'pending'].contains(order.paymentStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cancellation / Refund Request',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Submit a request when this order needs manual cancellation or refund handling.',
          ),
          const SizedBox(height: 12),
          requestsAsync.when(
            data: (requests) {
              final hasActiveRequest = requests.any((request) {
                return request.isActive;
              });

              if (requests.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('No request submitted yet'),
                    if (canRequest) ...[
                      const SizedBox(height: 12),
                      buildSubmitRefundRequestButton(order.id),
                    ],
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    requests.map((request) {
                      return buildReceiptRow(
                        '${request.requestType} (${request.status})',
                        request.reason,
                      );
                    }).toList()..addAll([
                      if (hasActiveRequest) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Request is already submitted and waiting for admin handling.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                      if (canRequest && !hasActiveRequest) ...[
                        const SizedBox(height: 12),
                        buildSubmitRefundRequestButton(order.id),
                      ],
                    ]),
              );
            },
            error: (error, stackTrace) {
              return Text(error.toString());
            },
            loading: () {
              return const LinearProgressIndicator();
            },
          ),
        ],
      ),
    );
  }

  Widget buildSubmitRefundRequestButton(String orderId) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isSubmittingRequest
            ? null
            : () => showRefundRequestDialog(orderId),
        icon: isSubmittingRequest
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.assignment_return_outlined),
        label: const Text('Submit Request'),
      ),
    );
  }

  Widget buildReceipt(OrderDetailModel order) {
    var subtotal = 0;

    for (final item in order.items) {
      subtotal += item.subtotal;
    }

    final shippingCost = order.totalAmount > subtotal
        ? order.totalAmount - subtotal
        : 0;

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
            'Invoice / Receipt',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Official order summary for this transaction.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          buildReceiptRow('Order Number', order.orderNumber),
          buildReceiptRow(
            'Order Date',
            DateFormatter.formatDateTime(order.createdAt.toString()),
          ),
          buildReceiptRow('Customer', order.shippingName),
          buildReceiptRow('Payment Status', order.paymentStatus),
          buildReceiptRow('Order Status', order.status),
          const Divider(height: 24),
          ...order.items.map((item) {
            return buildReceiptRow(
              '${item.productName} x${item.quantity}',
              CurrencyFormatter.format(item.subtotal),
            );
          }),
          const Divider(height: 24),
          buildReceiptRow('Subtotal', CurrencyFormatter.format(subtotal)),
          buildReceiptRow('Shipping', CurrencyFormatter.format(shippingCost)),
          const Divider(height: 24),
          buildReceiptRow(
            'Total',
            CurrencyFormatter.format(order.totalAmount),
            isStrong: true,
          ),
        ],
      ),
    );
  }

  Widget buildShipmentProgress(OrderDetailModel order) {
    final hasShipment =
        order.shippingProvider != null || order.trackingNumber != null;
    final isShipped = ['shipped', 'completed'].contains(order.status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shipment Progress',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isShipped
                ? 'Package has been shipped.'
                : 'Waiting for seller shipment.',
          ),
          const SizedBox(height: 8),
          buildReceiptRow('Courier', order.shippingProvider ?? '-'),
          buildReceiptRow('Tracking Number', order.trackingNumber ?? '-'),
          if (order.shippedAt != null)
            buildReceiptRow(
              'Shipped At',
              DateFormatter.formatDateTime(order.shippedAt.toString()),
            ),
          if (!hasShipment)
            const Text(
              'Courier and tracking number will appear after seller ships the order.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget buildReceiptRow(String label, String value, {bool isStrong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isStrong ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemReviewButton extends ConsumerWidget {
  final String orderId;
  final String productId;
  final bool isDeliveredOrCompleted;

  const _OrderItemReviewButton({
    required this.orderId,
    required this.productId,
    required this.isDeliveredOrCompleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDeliveredOrCompleted) return const SizedBox.shrink();

    final existingReview = productId.isEmpty
        ? null
        : ref
              .watch(
                orderProductReviewProvider((
                  productId: productId,
                  orderId: orderId,
                )),
              )
              .asData
              ?.value;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            if (productId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID Produk tidak ditemukan.')),
              );
              return;
            }
            await showDialog(
              context: context,
              builder: (context) => ProductReviewDialog(
                productId: productId,
                orderId: orderId,
                existingReview: existingReview,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: existingReview != null
                ? AppColors.primaryLight
                : AppColors.primary,
            foregroundColor: existingReview != null
                ? AppColors.primaryHover
                : Colors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: existingReview != null
                  ? const BorderSide(color: AppColors.primary, width: 1.5)
                  : BorderSide.none,
            ),
          ),
          icon: Icon(
            existingReview != null ? Icons.edit_note_rounded : Icons.star_rate_rounded,
            size: 20,
          ),
          label: Text(
            existingReview != null
                ? 'Edit Ulasan Saya (${existingReview.rating}★)'
                : 'Beri Ulasan Produk Ini',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
