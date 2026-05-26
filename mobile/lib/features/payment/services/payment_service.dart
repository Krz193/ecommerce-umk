import 'package:mobile/core/config/supabase_provider.dart';

class PaymentService {
  Future<Map<String, dynamic>>
  checkPaymentStatus({
    required String orderId,
  }) async {
    final response = await supabase.functions.invoke(
      'check-payment-status',

      body: {
        'order_id': orderId,
      },
    );

    if (response.status != 200) {
      throw Exception(
        response.data['error'] ??
            'Failed to check payment',
      );
    }

    return response.data;
  }
}