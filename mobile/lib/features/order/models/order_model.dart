class OrderModel {
  final String id;

  final String orderNumber;

  final String status;

  final String paymentStatus;

  final int totalAmount;

  final String? userId;

  final String? shippingName;

  final String? shippingProvider;

  final String? trackingNumber;

  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    this.userId,
    this.shippingName,
    this.shippingProvider,
    this.trackingNumber,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],

      orderNumber: json['order_number'],

      status: json['status'],

      paymentStatus: json['payment_status'],

      totalAmount: (json['total_amount'] as num).toInt(),

      userId: json['user_id'],

      shippingName: json['shipping_name'],

      shippingProvider: json['shipping_provider'],

      trackingNumber: json['tracking_number'],

      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
