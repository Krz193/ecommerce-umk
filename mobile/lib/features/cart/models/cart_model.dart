import 'package:mobile/features/cart/models/cart_item_model.dart';

class CartModel {
  final String id;

  final String storeId;

  final List<CartItemModel> items;

  CartModel({
    required this.id,
    required this.storeId,
    required this.items,
  });

  int get totalItems {
    return items.fold(
      0,
      (total, item) => total + item.quantity,
    );
  }

  int get subtotal {
    return items.fold(
      0,
      (total, item) => total + item.subtotal,
    );
  }
}