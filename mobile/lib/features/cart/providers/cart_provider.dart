import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/config/supabase_provider.dart';

import 'package:mobile/features/cart/models/cart_item_model.dart';
import 'package:mobile/features/cart/models/cart_model.dart';

final cartProvider = FutureProvider.autoDispose<List<CartModel>>((ref) async {
  final user = supabase.auth.currentUser;

  if (user == null) {
    return [];
  }

  final carts = await supabase.from('carts').select().eq('user_id', user.id);

  if (carts.isEmpty) {
    return [];
  }

  final List<CartModel> result = [];

  for (final cart in carts) {
    final cartItems = await supabase
        .from('cart_items')
        .select('''
          *,
          product:products (
            id,
            name,
            price,
            stock
          )
        ''')
        .eq('cart_id', cart['id']);

    final items = cartItems
        .map<CartItemModel>((json) => CartItemModel.fromJson(json))
        .toList();

    result.add(
      CartModel(id: cart['id'], storeId: cart['store_id'], items: items),
    );
  }

  return result;
});
