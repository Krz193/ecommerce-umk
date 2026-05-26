class OrderItemModel {
  final String id;

  final String productName;

  final int productPrice;

  final int quantity;

  final int subtotal;

  OrderItemModel({
    required this.id,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(
    Map<String, dynamic> json,
  ) {

    return OrderItemModel(
      id: json['id'],

      productName:
          json['product_name'],

      productPrice:
          json['product_price'],

      quantity:
          json['quantity'],

      subtotal:
          json['subtotal'],
    );
  }
}

class OrderDetailModel {
  final String id;

  final String orderNumber;

  final int totalAmount;

  final String paymentStatus;

  final DateTime createdAt;

  final List<OrderItemModel> items;

  OrderDetailModel({
    required this.id,
    required this.orderNumber,
    required this.totalAmount,
    required this.paymentStatus,
    required this.createdAt,
    required this.items,
  });

  factory OrderDetailModel.fromJson(
    Map<String, dynamic> json,
  ) {

    return OrderDetailModel(
      id: json['id'],

      orderNumber:
          json['order_number'],

      totalAmount:
          json['total_amount'],

      paymentStatus:
          json['payment_status'],

      createdAt: DateTime.parse(
        json['created_at'],
      ),

      items:
          (json['order_items'] as List)
              .map(
                (item) =>
                    OrderItemModel.fromJson(
                  item,
                ),
              )
              .toList(),
    );
  }
}