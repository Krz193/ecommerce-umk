import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/config/supabase_provider.dart';

import 'package:mobile/features/order/models/order_model.dart';

final ordersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final response = await supabase
      .from('orders')
      .select()
      .order('created_at', ascending: false);

  return response.map<OrderModel>((json) => OrderModel.fromJson(json)).toList();
});
