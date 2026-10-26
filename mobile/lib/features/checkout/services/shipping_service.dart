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

      final options = pricingList
          .map(
            (item) => ShippingRateOption.fromMap(item as Map<String, dynamic>),
          )
          .toList();

      // Mirror rate from external instant courier (e.g. Gojek/Grab Instant) to Ojek Lokal UMKM
      final instantOption = options.cast<ShippingRateOption?>().firstWhere(
            (opt) => opt != null && (opt.courierCode == 'gojek' || opt.courierCode == 'grab' || opt.serviceType == 'instant'),
            orElse: () => null,
          );

      // Default/mirrored price for local ojek
      final localOjekPrice = instantOption?.price ?? 15000;
      final localOjekDuration = instantOption?.durationRange ?? '1 - 2';
      final localOjekUnit = instantOption?.durationUnit ?? 'hours';

      final localOjekOption = ShippingRateOption(
        courierName: 'Ojek Lokal UMKM',
        courierCode: 'ojek_lokal',
        courierServiceName: 'Pengantaran Instan (Driver Mitra)',
        courierServiceCode: 'instant_lokal',
        serviceType: 'instant',
        price: localOjekPrice,
        durationRange: localOjekDuration,
        durationUnit: localOjekUnit,
        description: 'Diantar langsung oleh mitra driver ojek lokal komunitas UMKM',
      );

      // Insert Ojek Lokal at the top of the options list
      options.insert(0, localOjekOption);

      return options;
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
