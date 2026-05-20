class ProductModel {
  final String id;

  final String name;

  final int price;

  final int stock;

  final String status;

  final String? description;

  final String storeId;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.status,
    this.description,
    required this.storeId,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      name: json['name'],

      price: (json['price'] as num).toInt(),

      stock: (json['stock'] as num).toInt(),

      status: json['status'],

      description: json['description'],

      storeId: json['store_id'],
    );
  }
}
