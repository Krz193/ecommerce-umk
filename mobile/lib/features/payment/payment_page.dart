import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';

import 'providers/payment_provider.dart';

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
  ConsumerState<PaymentPage> createState() =>
      _PaymentPageState();
}

class _PaymentPageState
    extends ConsumerState<PaymentPage> {

  Timer? pollingTimer;

  late String transactionStatus;

  Color getStatusColor() {
    switch (transactionStatus) {
      case 'settlement':
        return Colors.green;

      case 'pending':
        return Colors.orange;

      case 'expire':
        return Colors.red;

      case 'cancel':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  String getStatusLabel() {
    switch (transactionStatus) {
      case 'settlement':
        return 'Paid';

      case 'pending':
        return 'Waiting Payment';

      case 'expire':
        return 'Expired';

      case 'cancel':
        return 'Cancelled';

      default:
        return transactionStatus;
    }
  }

  Future<void> checkPaymentStatus() async {
    try {
      final paymentService =
          ref.read(paymentServiceProvider);

      final result =
          await paymentService.checkPaymentStatus(
        orderId: widget.order['id'],
      );

      final status =
          result['transaction_status'];

      if (!mounted) return;

      setState(() {
        transactionStatus = status;
      });

      if (status == 'settlement') {
        pollingTimer?.cancel();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment success',
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  @override
  void initState() {
    super.initState();

    transactionStatus = widget.payment['status'];

    pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        checkPaymentStatus();
      },
    );
  }

  @override
  void dispose() {
    pollingTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vaNumber =
        widget.midtrans['permata_va_number'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Text(
              getStatusLabel(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),

              decoration: BoxDecoration(
                color: getStatusColor()
                    .withValues(alpha: 0.15),

                borderRadius:
                    BorderRadius.circular(999),
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

            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(16),
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    'Order: ${widget.order['order_number']}',
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Total: ${CurrencyFormatter.format(widget.order['total_amount'])}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text('Payment Method'),

                  const SizedBox(height: 8),

                  const Text(
                    'Permata Virtual Account',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
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
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      IconButton(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text: vaNumber,
                            ),
                          );

                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'VA copied',
                              ),
                            ),
                          );
                        },

                        icon: const Icon(
                          Icons.copy,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Expired: ${DateFormatter.formatDateTime(widget.payment['expired_at'])}',
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