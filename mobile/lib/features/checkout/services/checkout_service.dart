import 'package:mobile/core/config/supabase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckoutService {
  final SupabaseClient _supabase = supabase;

  Future<Map<String, dynamic>> checkout({
    required String cartId,
    required String addressId,
  }) async {
    final response = await _supabase.functions.invoke(
      'checkout',
      body: {
        'cart_id': cartId,
        'address_id': addressId,
      },
    );

    if (response.status != 200) {
      throw Exception(
        response.data is Map
            ? response.data['message'] ?? 'Checkout failed'
            : 'Checkout failed',
      );
    }

    return response.data;
  }
}