import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/checkout/services/checkout_service.dart';

final checkoutServiceProvider =
    Provider<CheckoutService>((ref) {
  return CheckoutService();
});