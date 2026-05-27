import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';

import 'package:mobile/features/payment/providers/payment_provider.dart';
import 'package:mobile/features/cart/services/cart_service.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/features/product/providers/product_provider.dart';
import 'package:mobile/features/order/providers/order_detail_provider.dart';
import 'package:mobile/features/order/providers/orders_provider.dart';

import 'package:go_router/go_router.dart';

class PaymentPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;

  final Map<String, dynamic> payment;

  final Map<String, dynamic> midtrans;

  const PaymentPage({
    super.key,
    required this.order,
    required this.payment,
    required this.midtrans,
  });

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  Timer? countdownTimer;
  Timer? paymentPollingTimer;

  late String transactionStatus;

  Duration remainingTime = Duration.zero;

  final cartService = CartService();

  Color getStatusColor() {
    switch (transactionStatus) {
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

  String getStatusLabel() {
    switch (transactionStatus) {
      case 'paid':
        return 'Paid';

      case 'pending':
        return 'Waiting Payment';

      case 'expired':
        return 'Expired';

      case 'failed':
        return 'Failed';

      default:
        return transactionStatus;
    }
  }

  void updateRemainingTime() {
    final expiredAt = DateTime.parse(widget.payment['expired_at']).toUtc();
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final difference = expiredAt.difference(now);

    if (!mounted) return;

    final isExpired = difference.isNegative;

    setState(() {
      remainingTime = isExpired ? Duration.zero : difference;

      if (isExpired && transactionStatus == 'pending') {
        transactionStatus = 'expired';
      }
    });
  }

  String formatRemainingTime() {
    final hours = remainingTime.inHours;

    final minutes = remainingTime.inMinutes % 60;

    final seconds = remainingTime.inSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Widget buildPaymentInstructions() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: const [
          Text(
            'Payment Instructions',

            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 16),

          Text('1. Open your banking app or ATM.'),

          SizedBox(height: 8),

          Text('2. Choose Virtual Account payment.'),

          SizedBox(height: 8),

          Text('3. Enter the VA number above.'),

          SizedBox(height: 8),

          Text('4. Complete payment before expiry time.'),
        ],
      ),
    );
  }

  Future<void> checkPaymentStatus() async {
    if (transactionStatus == 'expired') {
      return;
    }
    try {
      final paymentService = ref.read(paymentServiceProvider);

      final result = await paymentService.checkPaymentStatus(
        orderId: widget.order['id'],
      );

      final status = result['payment_status'];

      if (!mounted) return;

      setState(() {
        transactionStatus = status;
      });

      if (status == 'paid' || status == 'expired' || status == 'failed') {
        countdownTimer?.cancel();

        paymentPollingTimer?.cancel();

        ref.invalidate(ordersProvider);
        ref.invalidate(orderDetailProvider(widget.order['id']));

        if (status == 'paid') {
          final cartState = ref.read(cartProvider);

          final carts = cartState.asData?.value;

          if (carts != null && carts.isNotEmpty) {
            await cartService.clearCart(cartId: carts.first.id);

            ref.invalidate(cartProvider);
          }

          ref.invalidate(productsProvider);

          if (!mounted) return;

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Payment success')));
        }
      }
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  @override
  void initState() {
    super.initState();

    transactionStatus = widget.payment['status'];

    updateRemainingTime();

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (context) {
      updateRemainingTime();
    });

    paymentPollingTimer = Timer.periodic(const Duration(seconds: 5), (context) {
      debugPrint('checking payment status');

      checkPaymentStatus();
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();

    paymentPollingTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vaNumber = widget.midtrans['permata_va_number'];

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              getStatusLabel(),

              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

              decoration: BoxDecoration(
                color: getStatusColor().withValues(alpha: 0.15),

                borderRadius: BorderRadius.circular(999),
              ),

              child: Text(
                getStatusLabel(),

                style: TextStyle(
                  color: getStatusColor(),

                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 24),

            transactionStatus == 'paid'
                ? Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(24),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,

                          color: Colors.green,

                          size: 72,
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Payment Successful',

                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Order ${widget.order['order_number']} has been paid.',

                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,

                          child: ElevatedButton(
                            onPressed: () {
                              context.go('/home');
                            },

                            child: const Text('Back to Home'),
                          ),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,

                          child: OutlinedButton(
                            onPressed: () {
                              context.push('/orders/${widget.order['id']}');
                            },

                            child: const Text('View Orders'),
                          ),
                        ),
                      ],
                    ),
                  )
                : transactionStatus == 'pending'
                ? Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text('Order: ${widget.order['order_number']}'),

                        const SizedBox(height: 12),

                        Text(
                          'Total: ${CurrencyFormatter.format(widget.order['total_amount'])}',

                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 12),

                        const Text('Payment Method'),

                        const SizedBox(height: 8),

                        const Text(
                          'Permata Virtual Account',

                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 16),

                        const Text('VA Number'),

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                vaNumber,

                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            IconButton(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: vaNumber),
                                );

                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('VA copied')),
                                );
                              },

                              icon: const Icon(Icons.copy),
                            ),
                          ],
                        ),

                        Container(
                          width: double.infinity,

                          padding: const EdgeInsets.all(16),

                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),

                            borderRadius: BorderRadius.circular(12),
                          ),

                          child: Column(
                            children: [
                              const Text('Complete payment before'),

                              const SizedBox(height: 8),

                              Text(
                                formatRemainingTime(),

                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        buildPaymentInstructions(),

                        const SizedBox(height: 16),

                        Text(
                          'Expired: ${DateFormatter.formatDateTime(widget.payment['expired_at'])} WIB (UTC+7)',
                        ),
                      ],
                    ),
                  )
                : Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(24),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Column(
                      children: [
                        const Icon(
                          Icons.access_time_filled,

                          color: Colors.red,

                          size: 72,
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Payment Expired',

                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'This payment session has expired.',

                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,

                          child: ElevatedButton(
                            onPressed: () {
                              context.go('/cart');
                            },

                            child: const Text('Back to Cart'),
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
