import 'package:mobile/features/order/models/order_payment_model.dart';

class OrderItemModel {
  final String id;
  final String productId;
  final String productName;
  final int productPrice;
  final int quantity;
  final int subtotal;
  final String? productThumbnail;

  OrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.subtotal,
    this.productThumbnail,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'],
      productId: json['product_id'] ?? '',
      productName: json['product_name'],
      productPrice: (json['product_price'] as num).toInt(),
      quantity: json['quantity'],
      subtotal: (json['subtotal'] as num).toInt(),
      productThumbnail: json['product_thumbnail'],
    );
  }
}

class OrderDetailModel {
  final String id;
  final String orderNumber;
  final String status;
  final int totalAmount;
  final int subtotal;
  final int shippingCost;
  final String paymentStatus;
  final String shippingName;
  final String shippingPhone;
  final String shippingAddress;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? completedAt;
  final String? shippingProvider;
  final String? courierName;
  final String? courierCode;
  final String? courierServiceType;
  final String? trackingNumber;
  final String? waybillId;
  final String? driverName;
  final String? driverPhone;
  final String? trackingStatus;
  final List<OrderItemModel> items;
  final OrderPaymentModel? payment;

  OrderDetailModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    this.subtotal = 0,
    this.shippingCost = 0,
    required this.paymentStatus,
    required this.shippingName,
    required this.shippingPhone,
    required this.shippingAddress,
    required this.createdAt,
    required this.paidAt,
    required this.shippedAt,
    required this.completedAt,
    required this.shippingProvider,
    this.courierName,
    this.courierCode,
    this.courierServiceType,
    required this.trackingNumber,
    this.waybillId,
    this.driverName,
    this.driverPhone,
    this.trackingStatus,
    required this.items,
    required this.payment,
  });

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    return OrderDetailModel(
      id: json['id'],
      orderNumber: json['order_number'],
      status: json['status'],
      totalAmount: (json['total_amount'] as num).toInt(),
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      shippingCost: (json['shipping_cost'] as num?)?.toInt() ?? 0,
      paymentStatus: json['payment_status'],
      shippingName: json['shipping_name'] ?? '',
      shippingPhone: json['shipping_phone'] ?? '',
      shippingAddress: json['shipping_address'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      shippedAt: json['shipped_at'] != null
          ? DateTime.parse(json['shipped_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      shippingProvider: json['shipping_provider'],
      courierName: json['courier_name'] ?? json['shipping_provider'],
      courierCode: json['courier_code'],
      courierServiceType: json['courier_service_type'],
      trackingNumber: json['tracking_number'],
      waybillId: json['waybill_id'] ?? json['tracking_number'],
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
      trackingStatus: json['tracking_status'],
      items: (json['order_items'] as List? ?? [])
          .map((item) => OrderItemModel.fromJson(item))
          .toList(),
      payment: json['payment'] != null
          ? OrderPaymentModel.fromJson(json['payment'])
          : null,
    );
  }

  bool get isInstantCourier =>
      courierServiceType == 'instant' ||
      courierCode == 'gojek' ||
      courierCode == 'grab';
}
