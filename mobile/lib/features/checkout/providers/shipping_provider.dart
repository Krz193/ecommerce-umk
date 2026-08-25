import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/checkout/models/shipping_rate_model.dart';
import 'package:mobile/features/checkout/services/shipping_service.dart';

final shippingServiceProvider = Provider<ShippingService>((ref) {
  return ShippingService();
});

class ShippingRatesParam {
  final String cartId;
  final String addressId;

  ShippingRatesParam({required this.cartId, required this.addressId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShippingRatesParam &&
          runtimeType == other.runtimeType &&
          cartId == other.cartId &&
          addressId == other.addressId;

  @override
  int get hashCode => cartId.hashCode ^ addressId.hashCode;
}

final shippingRatesFamily = FutureProvider.autoDispose
    .family<List<ShippingRateOption>, ShippingRatesParam>((ref, param) async {
      final service = ref.watch(shippingServiceProvider);
      return service.fetchRates(
        cartId: param.cartId,
        addressId: param.addressId,
      );
    });

class SelectedShippingRateNotifier extends Notifier<ShippingRateOption?> {
  @override
  ShippingRateOption? build() => null;

  void selectRate(ShippingRateOption rate) {
    state = rate;
  }

  void reset() {
    state = null;
  }
}

final selectedShippingRateProvider =
    NotifierProvider.autoDispose<
      SelectedShippingRateNotifier,
      ShippingRateOption?
    >(SelectedShippingRateNotifier.new);
