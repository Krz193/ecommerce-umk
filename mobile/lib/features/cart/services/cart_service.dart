import 'package:mobile/core/config/supabase_provider.dart';

class CartService {
  Future<void> addToCart({
    required String productId,
    required String storeId,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    /*
    |--------------------------------------------------------------------------
    | Find Existing Cart
    |--------------------------------------------------------------------------
    */

    final existingCart = await supabase
        .from('carts')
        .select()
        .eq('user_id', user.id)
        .eq('store_id', storeId)
        .maybeSingle();

    Map<String, dynamic>? cart = existingCart;

    /*
    |--------------------------------------------------------------------------
    | Create Cart If Missing
    |--------------------------------------------------------------------------
    */

    cart ??= await supabase
        .from('carts')
        .insert({'user_id': user.id, 'store_id': storeId})
        .select()
        .single();

    /*
    |--------------------------------------------------------------------------
    | Check Existing Cart Item
    |--------------------------------------------------------------------------
    */

    final existingCartItem = await supabase
        .from('cart_items')
        .select()
        .eq('cart_id', cart['id'])
        .eq('product_id', productId)
        .maybeSingle();

    /*
    |--------------------------------------------------------------------------
    | Increment Quantity
    |--------------------------------------------------------------------------
    */

    if (existingCartItem != null) {
      await supabase
          .from('cart_items')
          .update({'quantity': existingCartItem['quantity'] + 1})
          .eq('id', existingCartItem['id']);

      return;
    }

    /*
    |--------------------------------------------------------------------------
    | Insert New Cart Item
    |--------------------------------------------------------------------------
    */

    await supabase.from('cart_items').insert({
      'cart_id': cart['id'],
      'product_id': productId,
      'quantity': 1,
    });
  }

  Future<void> updateCartQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    /*
    |--------------------------------------------------------------------------
    | Remove Item If Quantity <= 0
    |--------------------------------------------------------------------------
    */

    if (quantity <= 0) {
      await removeCartItem(cartItemId: cartItemId);

      return;
    }

    /*
    |--------------------------------------------------------------------------
    | Update Quantity
    |--------------------------------------------------------------------------
    */

    await supabase
        .from('cart_items')
        .update({'quantity': quantity})
        .eq('id', cartItemId);
  }

  Future<void> removeCartItem({required String cartItemId}) async {
    await supabase.from('cart_items').delete().eq('id', cartItemId);
  }

  Future<void> clearCart({required String cartId}) async {
    await supabase.from('cart_items').delete().eq('cart_id', cartId);

    await supabase.from('carts').delete().eq('id', cartId);
  }
}
