import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/order/models/order_detail_model.dart';
import 'package:mobile/features/order/providers/refund_request_provider.dart';
import 'package:mobile/features/order/providers/seller_order_provider.dart';
import 'package:mobile/features/order/widgets/refund_request_dialog.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerOrderDetailPage extends ConsumerStatefulWidget {
  final String orderId;

  const SellerOrderDetailPage({super.key, required this.orderId});

  @override
  ConsumerState<SellerOrderDetailPage> createState() =>
      _SellerOrderDetailPageState();
}

class _SellerOrderDetailPageState extends ConsumerState<SellerOrderDetailPage> {
  bool isUpdating = false;
  bool isSubmittingRequest = false;

  Future<void> showShipOrderDialog({required String storeId}) async {
    final providerController = TextEditingController();
    final trackingController = TextEditingController();

    final result = await showDialog<({String provider, String tracking})>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Shipment Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: providerController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Courier'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: trackingController,
                decoration: const InputDecoration(labelText: 'Tracking Number'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final provider = providerController.text.trim();
                final tracking = trackingController.text.trim();

                if (provider.isEmpty || tracking.isEmpty) {
                  return;
                }

                Navigator.of(
                  context,
                ).pop((provider: provider, tracking: tracking));
              },
              child: const Text('Ship Order'),
            ),
          ],
        );
      },
    );

    providerController.dispose();
    trackingController.dispose();

    if (result == null) {
      return;
    }

    await shipOrder(
      storeId: storeId,
      shippingProvider: result.provider,
      trackingNumber: result.tracking,
    );
  }

  Future<void> shipOrder({
    required String storeId,
    required String shippingProvider,
    required String trackingNumber,
  }) async {
    setState(() {
      isUpdating = true;
    });

    try {
      final service = ref.read(sellerOrderServiceProvider);

      await service.shipOrder(
        orderId: widget.orderId,
        shippingProvider: shippingProvider,
        trackingNumber: trackingNumber,
      );

      if (!mounted) {
        return;
      }

      ref.invalidate(sellerOrdersProvider(storeId));
      ref.invalidate(
        sellerOrderDetailProvider(
          SellerOrderDetailParams(storeId: storeId, orderId: widget.orderId),
        ),
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order shipped')));
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
        requesterRole: 'seller',
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

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Store Order Detail')),
      body: storeAsync.when(
        data: (store) {
          if (store == null) {
            return const Center(child: Text('Store not found'));
          }

          final params = SellerOrderDetailParams(
            storeId: store.id,
            orderId: widget.orderId,
          );

          final orderAsync = ref.watch(sellerOrderDetailProvider(params));

          return orderAsync.when(
            data: (order) {
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(sellerOrderDetailProvider(params));
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    buildOrderSummary(store.id, order),
                    const SizedBox(height: 16),
                    buildShipmentSection(store.id, order),
                    const SizedBox(height: 16),
                    buildRefundRequestSection(order),
                    const SizedBox(height: 16),
                    buildItems(order.items),
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

  Widget buildOrderSummary(String storeId, OrderDetailModel order) {
    final canShip =
        order.status == 'processing' && order.paymentStatus == 'paid';

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
            order.orderNumber,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              buildBadge(order.status, getOrderStatusColor(order.status)),
              buildBadge(
                order.paymentStatus,
                getPaymentStatusColor(order.paymentStatus),
              ),
            ],
          ),
          if (order.shippedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Shipped: ${DateFormatter.formatDateTime(order.shippedAt.toString())}',
            ),
          ],
          if (order.shippingProvider != null ||
              order.trackingNumber != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Shipment details are recorded below.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
          if (order.completedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Completed: ${DateFormatter.formatDateTime(order.completedAt.toString())}',
            ),
          ],
          if (canShip) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isUpdating
                    ? null
                    : () {
                        showShipOrderDialog(storeId: storeId);
                      },
                child: isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Ship Order'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildShipmentSection(String storeId, OrderDetailModel order) {
    final canShip =
        order.status == 'processing' && order.paymentStatus == 'paid';

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
            'Shipment Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(canShip ? 'Ready to ship' : 'Shipment status: ${order.status}'),
          const SizedBox(height: 12),
          buildInfoRow('Courier', order.shippingProvider ?? '-'),
          buildInfoRow('Tracking Number', order.trackingNumber ?? '-'),
          if (order.shippedAt != null)
            buildInfoRow(
              'Shipped At',
              DateFormatter.formatDateTime(order.shippedAt.toString()),
            ),
          if (order.completedAt != null)
            buildInfoRow(
              'Completed At',
              DateFormatter.formatDateTime(order.completedAt.toString()),
            ),
          if (canShip) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isUpdating
                    ? null
                    : () {
                        showShipOrderDialog(storeId: storeId);
                      },
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Input Courier and Tracking'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildRefundRequestSection(OrderDetailModel order) {
    final requestsAsync = ref.watch(refundRequestsProvider(order.id));
    final canRequest =
        order.status != 'cancelled' &&
        order.status != 'completed' &&
        ['paid', 'pending'].contains(order.paymentStatus);

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
            'Cancellation / Refund Request',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a manual handling request when seller-side cancellation or refund follow-up is needed.',
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
                      return buildInfoRow(
                        '${request.requesterRole} ${request.requestType}',
                        '${request.status}: ${request.reason}',
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

  Widget buildInfoRow(String label, String value) {
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildItems(List<OrderItemModel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Items',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(CurrencyFormatter.format(item.productPrice)),
                const SizedBox(height: 8),
                Text('Quantity: ${item.quantity}'),
                const SizedBox(height: 8),
                Text('Subtotal: ${CurrencyFormatter.format(item.subtotal)}'),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color getOrderStatusColor(String status) {
    return switch (status) {
      'processing' => Colors.blue,
      'shipped' => Colors.deepPurple,
      'completed' => Colors.green,
      'cancelled' => Colors.red,
      _ => Colors.grey,
    };
  }

  Color getPaymentStatusColor(String status) {
    return switch (status) {
      'paid' => Colors.green,
      'pending' => Colors.orange,
      'expired' => Colors.red,
      'failed' => Colors.red,
      _ => Colors.grey,
    };
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
