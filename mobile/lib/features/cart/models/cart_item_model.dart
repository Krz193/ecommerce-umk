class CartItemModel {
  final String id;

  final int quantity;

  final String productId;

  final String productName;

  final int productPrice;

  final int productStock;

  final String? productThumbnail;

  CartItemModel({
    required this.id,
    required this.quantity,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.productStock,
    this.productThumbnail,
  });

  int get subtotal => productPrice * quantity;

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final product = json['product'];

    return CartItemModel(
      id: json['id'],

      quantity: (json['quantity'] as num).toInt(),

      productId: product['id'],

      productName: product['name'],

      productPrice: (product['price'] as num).toInt(),

      productStock: (product['stock'] as num).toInt(),

      productThumbnail: product['thumbnail_url'],
    );
  }
}
