import 'package:mobile/core/config/supabase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckoutService {
  final SupabaseClient _supabase = supabase;

  Future<Map<String, dynamic>> checkout({
    required String cartId,
    required String addressId,
    required String courierCode,
    required String courierServiceCode,
    String? voucherCode,
  }) async {
    final payload = <String, dynamic>{
      'cart_id': cartId,
      'address_id': addressId,
      'courier_code': courierCode,
      'courier_service_code': courierServiceCode,
    };

    if (voucherCode != null && voucherCode.trim().isNotEmpty) {
      payload['voucher_code'] = voucherCode.trim().toUpperCase();
    }

    final response = await _supabase.functions.invoke(
      'checkout',
      body: payload,
    );

    if (response.status != 200) {
      throw response.data;
    }

    return Map<String, dynamic>.from(response.data as Map);
  }
}
