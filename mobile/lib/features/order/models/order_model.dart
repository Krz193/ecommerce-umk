class OrderModel {
  final String id;

  final String orderNumber;

  final String status;

  final String paymentStatus;

  final int totalAmount;

  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    required this.createdAt,
  });

  factory OrderModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrderModel(
      id: json['id'],

      orderNumber: json['order_number'],

      status: json['status'],

      paymentStatus:
          json['payment_status'],

      totalAmount:
          (json['total_amount'] as num)
              .toInt(),

      createdAt: DateTime.parse(
        json['created_at'],
      ),
    );
  }
}