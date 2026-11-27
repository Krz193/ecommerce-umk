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

    final product = await supabase
        .from('products')
        .select('id, name, stock')
        .eq('id', productId)
        .maybeSingle();

    if (product == null) {
      throw Exception('Produk tidak ditemukan');
    }

    final availableStock = (product['stock'] as num?)?.toInt() ?? 0;
    if (availableStock <= 0) {
      throw Exception('Stok produk habis');
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
      final nextQty = (existingCartItem['quantity'] as num).toInt() + 1;
      if (nextQty > availableStock) {
        throw Exception('Stok tidak mencukupi (tersisa $availableStock)');
      }

      await supabase
          .from('cart_items')
          .update({'quantity': nextQty})
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

    final existing = await supabase
        .from('cart_items')
        .select('id, product:products(stock)')
        .eq('id', cartItemId)
        .maybeSingle();

    final product = existing?['product'] as Map<String, dynamic>?;
    final availableStock = (product?['stock'] as num?)?.toInt();
    if (availableStock != null && quantity > availableStock) {
      throw Exception('Stok tidak mencukupi (tersisa $availableStock)');
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
    final itemRow = await supabase
        .from('cart_items')
        .select('cart_id')
        .eq('id', cartItemId)
        .maybeSingle();

    await supabase.from('cart_items').delete().eq('id', cartItemId);

    final cartId = itemRow?['cart_id']?.toString();
    if (cartId != null && cartId.isNotEmpty) {
      final remaining = await supabase
          .from('cart_items')
          .select('id')
          .eq('cart_id', cartId)
          .limit(1);
      if (remaining.isEmpty) {
        await supabase.from('carts').delete().eq('id', cartId);
      }
    }
  }

  Future<void> clearCart({required String cartId}) async {
    await supabase.from('cart_items').delete().eq('cart_id', cartId);

    await supabase.from('carts').delete().eq('id', cartId);
  }
}
