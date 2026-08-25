import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/checkout/models/shipping_rate_model.dart';

class ShippingService {
  /// Calls Supabase Edge Function `shipping-rates` which interfaces with Biteship / Smart Mock Engine
  Future<List<ShippingRateOption>> fetchRates({
    required String cartId,
    required String addressId,
  }) async {
    try {
      final response = await supabase.functions.invoke(
        'shipping-rates',
        body: {'cart_id': cartId, 'address_id': addressId},
      );

      if (response.status != 200) {
        throw Exception(
          response.data?['error'] ?? 'Gagal mengambil pilihan pengiriman',
        );
      }

      final data = response.data;
      final pricingList = data['pricing'] as List<dynamic>? ?? [];

      return pricingList
          .map(
            (item) => ShippingRateOption.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      // Fallback default options in case of network edge failure
      return [
        ShippingRateOption(
          courierName: 'Gojek',
          courierCode: 'gojek',
          courierServiceName: 'Instant',
          courierServiceCode: 'instant',
          serviceType: 'instant',
          price: 15000,
          durationRange: '1 - 3',
          durationUnit: 'hours',
          description: 'Pengantaran kilat langsung sampai dalam 1-3 jam',
        ),
        ShippingRateOption(
          courierName: 'JNE',
          courierCode: 'jne',
          courierServiceName: 'Reguler (REG)',
          courierServiceCode: 'reg',
          serviceType: 'standard',
          price: 10000,
          durationRange: '1 - 2',
          durationUnit: 'days',
          description: 'Layanan ekspedisi reguler JNE terpercaya',
        ),
        ShippingRateOption(
          courierName: 'SiCepat',
          courierCode: 'sicepat',
          courierServiceName: 'SIUNTUNG',
          courierServiceCode: 'siuntung',
          serviceType: 'standard',
          price: 11000,
          durationRange: '1 - 2',
          durationUnit: 'days',
          description: 'Pengiriman cepat SiCepat Ekspres ke seluruh Indonesia',
        ),
      ];
    }
  }
}
