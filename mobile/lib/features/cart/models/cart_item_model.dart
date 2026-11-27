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
    final product = json['product'] as Map<String, dynamic>?;

    return CartItemModel(
      id: json['id']?.toString() ?? '',

      quantity: (json['quantity'] as num?)?.toInt() ?? 0,

      productId: product?['id']?.toString() ?? json['product_id']?.toString() ?? '',

      productName: product?['name']?.toString() ?? 'Produk tidak tersedia',

      productPrice: (product?['price'] as num?)?.toInt() ?? 0,

      productStock: (product?['stock'] as num?)?.toInt() ?? 0,

      productThumbnail: product?['thumbnail_url']?.toString(),
    );
  }
}
