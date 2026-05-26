import 'package:flutter/material.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/utils/date_formatter.dart';

class PaymentPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final vaNumber =
        midtrans['permata_va_number'];

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
            const Text(
              'Waiting Payment',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
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
                    'Order: ${order['order_number']}',
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Total: ${CurrencyFormatter.format(order['total_amount'])}',
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      IconButton(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: vaNumber),
                          );

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('VA copied'),
                            ),
                          );
                        },

                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Expired: ${DateFormatter.formatDateTime(payment['expired_at'])}',
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