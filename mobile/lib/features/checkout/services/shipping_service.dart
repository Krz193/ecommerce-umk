import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/checkout/models/shipping_rate_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShippingService {
  /// Calls Supabase Edge Function `shipping-rates` which interfaces with Biteship / Smart Mock Engine
  Future<List<ShippingRateOption>> fetchRates({
    required String cartId,
    required String addressId,
  }) async {
    try {
      final response = await supabase.functions
          .invoke('shipping-rates', body: {'cart_id': cartId, 'address_id': addressId})
          .timeout(const Duration(milliseconds: 5000));

      if (response.status != 200) {
        final errorMsg = response.data is Map
            ? response.data['error']?.toString()
            : null;
        throw Exception(errorMsg ?? 'Gagal memuat tarif pengiriman dari ekspedisi');
      }

      final data = response.data;
      if (data is! Map || data['pricing'] == null) {
        throw Exception('Data tarif tidak valid dari server');
      }

      final pricingList = data['pricing'] as List<dynamic>? ?? [];

      if (pricingList.isEmpty) {
        throw Exception('Tidak ada layanan kurir yang tersedia untuk rute alamat ini.');
      }

      return pricingList
          .map(
            (item) => ShippingRateOption.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } on FunctionException catch (fe) {
      String msg = 'Gagal memuat tarif kurir';
      if (fe.details is Map) {
        msg = (fe.details as Map)['error']?.toString() ?? msg;
      } else if (fe.details is String && (fe.details as String).isNotEmpty) {
        msg = fe.details as String;
      }
      throw Exception(msg);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Terjadi kendala saat memeriksa ongkos kirim: $e');
    }
  }
}
