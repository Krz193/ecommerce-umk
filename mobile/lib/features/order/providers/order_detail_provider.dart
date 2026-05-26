import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/config/supabase_provider.dart';

import 'package:mobile/features/order/models/order_detail_model.dart';

final orderDetailProvider = FutureProvider.family<
    OrderDetailModel,
    String>(
  (
    ref,
    orderId,
  ) async {

    final response = await supabase
        .from('orders')
        .select(
          '''
          *,
          payment:payments (
            id,
            status,
            expired_at,
            provider_transaction_id,
            raw_response
          ),
          order_items (
            id,
            product_name,
            product_price,
            quantity,
            subtotal
          )
          ''',
        )
        .eq('id', orderId)
        .single();

    return OrderDetailModel.fromJson(
      response,
    );
  },
);