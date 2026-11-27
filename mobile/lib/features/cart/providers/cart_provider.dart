import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/config/supabase_provider.dart';

import 'package:mobile/features/cart/models/cart_item_model.dart';
import 'package:mobile/features/cart/models/cart_model.dart';

final cartProvider = FutureProvider.autoDispose<List<CartModel>>((ref) async {
  final user = supabase.auth.currentUser;

  if (user == null) {
    return [];
  }

  final carts = await supabase
      .from('carts')
      .select('''
        id,
        store_id,
        cart_items (
          *,
          product:products (
            id,
            name,
            price,
            stock,
            thumbnail_url
          )
        )
      ''')
      .eq('user_id', user.id);

  if (carts.isEmpty) {
    return [];
  }

  return carts.map<CartModel>((cart) {
    final rawItems = cart['cart_items'] as List<dynamic>? ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map<CartItemModel>(CartItemModel.fromJson)
        .toList();

    return CartModel(id: cart['id'], storeId: cart['store_id'], items: items);
  }).toList();
});
