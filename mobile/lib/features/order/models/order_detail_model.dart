import 'package:mobile/features/order/models/order_payment_model.dart';

class OrderItemModel {
  final String id;

  final String productName;

  final int productPrice;

  final int quantity;

  final int subtotal;

  final String? productThumbnail;

  OrderItemModel({
    required this.id,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.subtotal,
    this.productThumbnail,
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

      productThumbnail:
          json['product_thumbnail'],
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

  final OrderPaymentModel? payment;

  OrderDetailModel({
    required this.id,
    required this.orderNumber,
    required this.totalAmount,
    required this.paymentStatus,
    required this.createdAt,
    required this.items,
    required this.payment,
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

      payment:
        json['payment'] != null
            ? OrderPaymentModel.fromJson(
                json['payment'],
              )
            : null,
    );
  }
}