class StockMovementModel {
  final String id;
  final String productId;
  final String storeId;
  final String movementType;
  final int quantity;
  final int previousStock;
  final int newStock;
  final String? note;
  final DateTime createdAt;

  const StockMovementModel({
    required this.id,
    required this.productId,
    required this.storeId,
    required this.movementType,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.note,
    required this.createdAt,
  });

  factory StockMovementModel.fromJson(Map<String, dynamic> json) {
    return StockMovementModel(
      id: json['id'],
      productId: json['product_id'],
      storeId: json['store_id'],
      movementType: json['movement_type'],
      quantity: (json['quantity'] as num).toInt(),
      previousStock: (json['previous_stock'] as num).toInt(),
      newStock: (json['new_stock'] as num).toInt(),
      note: json['note'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
