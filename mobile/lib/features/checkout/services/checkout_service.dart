import 'package:mobile/core/config/supabase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckoutService {
  final SupabaseClient _supabase = supabase;

  Future<Map<String, dynamic>> checkout({
    required String cartId,
    required String addressId,
    Map<String, dynamic>? selectedCourier,
    String? voucherId,
    String? voucherCode,
    int? voucherDiscount,
    int? donationAmount,
  }) async {
    final payload = <String, dynamic>{
      'cart_id': cartId,
      'address_id': addressId,
    };

    if (selectedCourier != null) {
      payload['selected_courier'] = selectedCourier;
    }
    if (voucherId != null) {
      payload['voucher_id'] = voucherId;
    }
    if (voucherCode != null) {
      payload['voucher_code'] = voucherCode;
    }
    if (voucherDiscount != null) {
      payload['voucher_discount'] = voucherDiscount;
    }
    if (donationAmount != null && donationAmount > 0) {
      payload['donation_amount'] = donationAmount;
    }

    final response = await _supabase.functions.invoke(
      'checkout',
      body: payload,
    );

    if (response.status != 200) {
      throw response.data;
    }

    return response.data;
  }
}
