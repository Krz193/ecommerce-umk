import 'package:mobile/core/config/supabase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckoutService {
  final SupabaseClient _supabase = supabase;

  Future<Map<String, dynamic>> checkout({
    required String cartId,
    required String addressId,
    Map<String, dynamic>? selectedCourier,
  }) async {
    final payload = <String, dynamic>{
      'cart_id': cartId,
      'address_id': addressId,
      'selected_courier': ?selectedCourier,
    };

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
