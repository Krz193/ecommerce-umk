import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/config/supabase_provider.dart';

import 'package:mobile/features/order/models/order_model.dart';

final ordersProvider = FutureProvider.autoDispose<List<OrderModel>>((
  ref,
) async {
  final user = supabase.auth.currentUser;

  if (user == null) {
    return [];
  }

  final response = await supabase
      .from('orders')
      .select()
      .eq('user_id', user.id)
      .order('created_at', ascending: false);

  return response.map<OrderModel>((json) => OrderModel.fromJson(json)).toList();
});
