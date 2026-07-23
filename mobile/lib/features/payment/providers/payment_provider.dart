import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/payment/services/payment_service.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});
