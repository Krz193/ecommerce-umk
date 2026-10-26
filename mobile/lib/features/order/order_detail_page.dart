import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/order/models/order_detail_model.dart';
import 'package:mobile/features/order/providers/order_detail_provider.dart';
import 'package:mobile/features/order/providers/order_status_provider.dart';
import 'package:mobile/features/order/providers/orders_provider.dart';
import 'package:mobile/features/order/providers/refund_request_provider.dart';
import 'package:mobile/features/order/widgets/in_app_call_dialog.dart';
import 'package:mobile/features/order/widgets/refund_request_dialog.dart';
import 'package:mobile/features/product/providers/product_review_providers.dart';
import 'package:mobile/features/product/widgets/product_review_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher/url_launcher.dart';

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
      appBar: AppBar(
        title: const Text('Order Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: () {
              ref.invalidate(orderDetailProvider(widget.orderId));
            },
          ),
        ],
      ),
      body: orderAsync.when(
        data: (order) {
          final timeline = buildTimeline(order);

          if (shouldStopPolling(order)) {
            stopPolling();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderDetailProvider(widget.orderId));
              await ref.read(orderDetailProvider(widget.orderId).future);
            },
            child: ListView(
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
                      if (order.shippingNotes != null &&
                          order.shippingNotes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Patokan: ${order.shippingNotes!}',
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
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

                const SizedBox(height: 24),
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

  String formatTrackingStatus(String? status) {
    if (status == null || status.isEmpty) return '-';
    switch (status.toLowerCase()) {
      case 'allocated':
        return 'Kurir Dialokasikan (Allocated)';
      case 'picking_up':
        return 'Kurir Menuju Penjemputan (Picking Up)';
      case 'picked':
        return 'Paket Telah Diambil Kurir (Picked)';
      case 'dropping_off':
      case 'on_delivery':
      case 'in_transit':
        return 'Dalam Pengiriman (On Delivery)';
      case 'delivered':
        return 'Paket Telah Sampai (Delivered)';
      case 'cancelled':
        return 'Pengiriman Dibatalkan';
      case 'rejected':
        return 'Pengiriman Ditolak';
      case 'courier_not_found':
        return 'Kurir Belum Ditemukan';
      default:
        return status.toUpperCase();
    }
  }

  Widget buildShipmentProgress(OrderDetailModel order) {
    final hasShipment =
        order.courierName != null ||
        order.shippingProvider != null ||
        order.waybillId != null;
    final isShipped = ['shipped', 'completed'].contains(order.status);
    final courierDisplay =
        order.courierName ?? order.shippingProvider ?? 'Kurir Standar';
    final waybillDisplay = order.waybillId ?? order.trackingNumber ?? '-';
    final hasDriverContact =
        (order.driverPhone != null && order.driverPhone!.trim().isNotEmpty) ||
        order.isInstantCourier ||
        isShipped;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                order.isInstantCourier
                    ? Icons.two_wheeler
                    : Icons.local_shipping,
                color: order.isInstantCourier ? Colors.green : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Status Pengiriman Logistik & GPS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: order.isInstantCourier
                      ? Colors.green.shade100
                      : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.isInstantCourier ? 'OJEK INSTANT' : 'EKSPEDISI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: order.isInstantCourier
                        ? Colors.green.shade900
                        : Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isShipped
                ? 'Paket sedang dalam proses pengiriman.'
                : 'Menunggu penjual memproses dan mengirim pesanan.',
            style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
          ),
          const SizedBox(height: 10),
          buildReceiptRow('Ekspedisi / Ojek', courierDisplay),
          buildReceiptRow('No. Resi / Tracking ID', waybillDisplay),
          if (order.driverName != null && order.driverName!.isNotEmpty)
            buildReceiptRow('Nama Driver', order.driverName!),
          if (order.driverPhone != null && order.driverPhone!.isNotEmpty)
            buildReceiptRow('No. Telepon Driver', order.driverPhone!),
          if (order.trackingStatus != null && order.trackingStatus!.isNotEmpty)
            buildReceiptRow(
              'Status Logistik',
              formatTrackingStatus(order.trackingStatus),
            ),
          if (order.shippedAt != null)
            buildReceiptRow(
              'Waktu Dikirim',
              DateFormatter.formatDateTime(order.shippedAt.toString()),
            ),

          const SizedBox(height: 12),

          // #9 GPS Pengiriman Visual Route & Live Coordinate Card
          _buildGpsShippingCard(order),

          // #10 Call Gojek & #11 Message Gojek Action Row
          if (hasDriverContact) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.green.shade700,
                        child: const Icon(
                          Icons.two_wheeler_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.driverName?.isNotEmpty == true
                                  ? order.driverName!
                                  : 'Driver ${order.isInstantCourier ? "Gojek / Ojek" : courierDisplay}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              order.driverPhone?.isNotEmpty == true
                                  ? order.driverPhone!
                                  : 'Siap dihubungi via Telepon / Pesan',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (order.driverMessages.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${order.driverMessages.length} pesan',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _callGojekDriver(order),
                          icon: const Icon(
                            Icons.phone_in_talk_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'Telepon Driver',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openMessageGojekSheet(order),
                          icon: const Icon(Icons.chat_rounded, size: 16),
                          label: const Text(
                            'Chat Driver',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade800,
                            side: BorderSide(color: Colors.green.shade700),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          if (!hasShipment) ...[
            const SizedBox(height: 8),
            const Text(
              'Detail kurir dan resi otomatis terupdate saat toko request pickup / kirim barang.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGpsShippingCard(OrderDetailModel order) {
    final progressPct = (order.gpsProgressFraction * 100).round();
    final distanceKm = order.estimatedDistanceKm.toStringAsFixed(1);
    final driverCoord =
        '${order.effectiveDriverLat.toStringAsFixed(5)}, ${order.effectiveDriverLng.toStringAsFixed(5)}';
    final storeCoord =
        '${order.effectiveStoreLat.toStringAsFixed(5)}, ${order.effectiveStoreLng.toStringAsFixed(5)}';
    final destCoord =
        '${order.effectiveDestLat.toStringAsFixed(5)}, ${order.effectiveDestLng.toStringAsFixed(5)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightBlue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gps_fixed_rounded,
                size: 18,
                color: Colors.blue.shade800,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'GPS Pengiriman & Rute Kurir ($distanceKm km)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade800,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$progressPct% Rute',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Visual Vector Route Map Widget
          _buildVisualRouteMap(order),

          _buildGpsCoordinateRow(
            icon: Icons.storefront_rounded,
            color: Colors.indigo,
            title: 'Titik Jemput (Toko UMK): ${order.storeName ?? "Toko UMK"}',
            subtitle: 'GPS: $storeCoord',
          ),
          const SizedBox(height: 6),
          _buildGpsCoordinateRow(
            icon: order.isInstantCourier
                ? Icons.two_wheeler_rounded
                : Icons.local_shipping_rounded,
            color: Colors.green.shade700,
            title:
                'Posisi GPS Kurir / Gojek (${formatTrackingStatus(order.trackingStatus)})',
            subtitle: 'GPS Aktif: $driverCoord',
          ),
          const SizedBox(height: 6),
          _buildGpsCoordinateRow(
            icon: Icons.location_on_rounded,
            color: Colors.red.shade700,
            title: 'Titik Tujuan (Pembeli): ${order.shippingName}',
            subtitle: 'GPS: $destCoord',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openGpsMapRoute(order),
                icon: const Icon(Icons.map_outlined, size: 15),
                label: const Text(
                  'Buka Rute di Google Maps',
                  style: TextStyle(fontSize: 11),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: driverCoord));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Koordinat GPS kurir ($driverCoord) disalin.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text(
                  'Salin Titik GPS',
                  style: TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualRouteMap(OrderDetailModel order) {
    final isDelivered =
        order.status == 'delivered' || order.trackingStatus == 'delivered';

    final storePos =
        ll.LatLng(order.effectiveStoreLat, order.effectiveStoreLng);
    final driverPos =
        ll.LatLng(order.effectiveDriverLat, order.effectiveDriverLng);
    final destPos =
        ll.LatLng(order.effectiveDestLat, order.effectiveDestLng);

    final bounds =
        LatLngBounds.fromPoints([storePos, driverPos, destPos]);

    return Container(
      height: 220,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Real Interactive OpenStreetMap
            FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 42, vertical: 38),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ecommerce.umk.mobile',
                ),
                PolylineLayer(
                  polylines: [
                    // Route casing
                    Polyline(
                      points: [storePos, driverPos, destPos],
                      strokeWidth: 6.0,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    // Route active polyline
                    Polyline(
                      points: [storePos, driverPos, destPos],
                      strokeWidth: 3.5,
                      color: order.isInstantCourier
                          ? const Color(0xFF10B981)
                          : const Color(0xFF0284C7),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Store Marker
                    Marker(
                      point: storePos,
                      width: 90,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade800,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black26, blurRadius: 3)
                              ],
                            ),
                            child: const Text(
                              'Toko UMK',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Icon(Icons.storefront_rounded,
                              color: Colors.indigo.shade800, size: 22),
                        ],
                      ),
                    ),

                    // Destination Marker
                    Marker(
                      point: destPos,
                      width: 90,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black26, blurRadius: 3)
                              ],
                            ),
                            child: const Text(
                              'Tujuan',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Icon(Icons.location_on_rounded,
                              color: Colors.red.shade700, size: 22),
                        ],
                      ),
                    ),

                    // Driver Marker
                    Marker(
                      point: driverPos,
                      width: 95,
                      height: 58,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade800,
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black26, blurRadius: 3)
                              ],
                            ),
                            child: Text(
                              order.isInstantCourier ? 'Ojek Lokal' : 'Kurir',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.shade600
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              order.isInstantCourier
                                  ? Icons.two_wheeler_rounded
                                  : Icons.local_shipping_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Top Overlay: Live Status Pill
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isDelivered
                          ? 'Paket Sampai'
                          : 'Live Map (${(order.gpsProgressFraction * 100).round()}%)',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top Right Overlay: Distance Pill
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4)
                  ],
                ),
                child: Text(
                  '${order.estimatedDistanceKm.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ),

            // Bottom Right Overlay: Zoom & OpenStreetMap Note
            Positioned(
              bottom: 6,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '© OpenStreetMap',
                  style: TextStyle(fontSize: 8, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsCoordinateRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openGpsMapRoute(OrderDetailModel order) async {
    final url =
        order.trackingUrl != null && order.trackingUrl!.trim().isNotEmpty
        ? order.trackingUrl!.trim()
        : 'https://www.google.com/maps/dir/?api=1'
              '&origin=${order.effectiveStoreLat},${order.effectiveStoreLng}'
              '&destination=${order.effectiveDestLat},${order.effectiveDestLng}'
              '&waypoints=${order.effectiveDriverLat},${order.effectiveDriverLng}'
              '&travelmode=driving';

    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka aplikasi peta GPS.')),
      );
    }
  }

  Future<void> _callGojekDriver(OrderDetailModel order) async {
    final rawPhone = (order.driverPhone ?? '').trim();
    final phone = rawPhone.isNotEmpty ? rawPhone : '081200001111';
    final driverTitle = order.driverName?.trim().isNotEmpty == true
        ? order.driverName!.trim()
        : 'Driver ${order.isInstantCourier ? "Gojek / Ojek" : (order.courierName ?? "Kurir")}';

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InAppCallDialog(
        orderId: order.id,
        orderNumber: order.orderNumber,
        remotePartyName: driverTitle,
        remotePartyPhone: phone,
        callerRole: 'buyer',
      ),
    );
  }

  Future<void> _openMessageGojekSheet(OrderDetailModel order) async {
    final messageController = TextEditingController();
    final rawPhone = (order.driverPhone ?? '').trim();
    final phone = rawPhone.isNotEmpty ? rawPhone : '081200001111';
    final waPhone = phone.startsWith('0')
        ? '62${phone.substring(1)}'
        : phone.replaceAll('+', '');

    final quickTemplates = const [
      'Halo Pak, mohon kabari jika sudah dekat ya.',
      'Titip di pos satpam / pagar depan ya Pak.',
      'Saya sudah menunggu di depan rumah.',
      'Patokan alamat sesuai catatan pesanan ya Pak.',
    ];

    RealtimeChannel? chatChannel;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        var messages = List<Map<String, dynamic>>.from(order.driverMessages);
        var isSending = false;
        var subscribed = false;

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            if (!subscribed) {
              subscribed = true;
              supabase
                  .from('orders')
                  .select('driver_messages')
                  .eq('id', order.id)
                  .maybeSingle()
                  .then((val) {
                if (val != null && val['driver_messages'] is List && sheetCtx.mounted) {
                  setSheetState(() {
                    messages = (val['driver_messages'] as List)
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();
                  });
                }
              });

              chatChannel = supabase
                  .channel('driver_chat:order_${order.id}')
                  .onPostgresChanges(
                    event: PostgresChangeEvent.update,
                    schema: 'public',
                    table: 'orders',
                    filter: PostgresChangeFilter(
                      type: PostgresChangeFilterType.eq,
                      column: 'id',
                      value: order.id,
                    ),
                    callback: (payload) {
                      final raw = payload.newRecord['driver_messages'];
                      if (raw is List && sheetCtx.mounted) {
                        setSheetState(() {
                          messages = raw
                              .whereType<Map>()
                              .map((e) => Map<String, dynamic>.from(e))
                              .toList();
                        });
                      }
                    },
                  )
                  .subscribe();
            }

            Future<void> sendInAppMessage(String text) async {
              final trimmed = text.trim();
              if (trimmed.isEmpty || isSending) return;
              setSheetState(() => isSending = true);
              try {
                final res = await supabase.rpc(
                  'append_order_driver_message',
                  params: {
                    'p_order_id': order.id,
                    'p_message': trimmed,
                    'p_sender_role': 'buyer',
                  },
                );
                messageController.clear();
                if (res is List) {
                  setSheetState(() {
                    messages = res
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();
                  });
                }
                ref.invalidate(orderDetailProvider(widget.orderId));
              } catch (e) {
                if (sheetCtx.mounted) {
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    SnackBar(content: Text('Gagal mengirim pesan: $e')),
                  );
                }
              } finally {
                if (sheetCtx.mounted) {
                  setSheetState(() => isSending = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.green.shade700,
                        child: const Icon(
                          Icons.two_wheeler_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chat ${order.driverName ?? "Driver Ojek / Kurir"}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Order ${order.orderNumber} • $phone',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Direct WhatsApp / SMS shortcuts
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final text = Uri.encodeComponent(
                              'Halo Pak ${order.driverName ?? "Driver"}, saya penerima pesanan ${order.orderNumber} (${order.shippingName}).',
                            );
                            final uri = Uri.parse(
                              'https://wa.me/$waPhone?text=$text',
                            );
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.open_in_new, size: 15),
                          label: const Text(
                            'Chat WhatsApp',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri(
                              scheme: 'sms',
                              path: phone,
                              queryParameters: {
                                'body':
                                    'Halo Pak, terkait pesanan ${order.orderNumber} ke ${order.shippingAddress}',
                              },
                            );
                            await launchUrl(uri);
                          },
                          icon: const Icon(Icons.sms_outlined, size: 15),
                          label: const Text(
                            'Kirim SMS',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Quick reply templates
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: quickTemplates.map((tpl) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(
                              tpl,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () => sendInAppMessage(tpl),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // In-app messages history
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: messages.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'Belum ada pesan in-app dengan driver. Pilih template cepat atau ketik pesan di bawah.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: messages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, idx) {
                              final msg = messages[idx];
                              final role =
                                  msg['sender_role']?.toString() ?? 'buyer';
                              final isBuyer = role == 'buyer';
                              return Align(
                                alignment: isBuyer
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isBuyer
                                        ? Colors.green.shade700
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isBuyer
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${msg['sender_name'] ?? 'Pengguna'} (${role.toUpperCase()})',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isBuyer
                                              ? Colors.white70
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        msg['message']?.toString() ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isBuyer
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),

                  // Message Input Box
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          decoration: const InputDecoration(
                            hintText: 'Tulis pesan ke driver Gojek / kurir...',
                            isDense: true,
                          ),
                          onSubmitted: sendInAppMessage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isSending
                            ? null
                            : () => sendInAppMessage(messageController.text),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Kirim'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (chatChannel != null) {
      await supabase.removeChannel(chatChannel!);
    }
    messageController.dispose();
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
            existingReview != null
                ? Icons.edit_note_rounded
                : Icons.star_rate_rounded,
            size: 20,
          ),
          label: Text(
            existingReview != null
                ? 'Edit Ulasan Saya (${existingReview.rating}★)'
                : 'Beri Ulasan Produk Ini',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
