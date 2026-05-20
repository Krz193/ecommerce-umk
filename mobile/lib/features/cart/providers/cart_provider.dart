import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/config/supabase_provider.dart';

import 'package:mobile/features/cart/models/cart_item_model.dart';

final cartProvider =
    FutureProvider<List<CartItemModel>>((
      ref,
    ) async {
      final user =
          supabase.auth.currentUser;

      if (user == null) {
        return [];
      }

      final carts = await supabase
          .from('carts')
          .select('id')
          .eq('user_id', user.id);

      if (carts.isEmpty) {
        return [];
      }

      final cartIds =
          carts
              .map<String>(
                (cart) => cart['id']
                    as String,
              )
              .toList();

      final response = await supabase
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
          .inFilter(
            'cart_id',
            cartIds,
          );

      return response
          .map<CartItemModel>(
            (json) =>
                CartItemModel.fromJson(
                  json,
                ),
          )
          .toList();
    });