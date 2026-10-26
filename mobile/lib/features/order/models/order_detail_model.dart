import 'dart:math' as math;

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
  final String? storeId;
  final String? storeName;
  final String? storeAddress;
  final double? storeLatitude;
  final double? storeLongitude;
  final String orderNumber;
  final String status;
  final int totalAmount;
  final int subtotal;
  final int shippingCost;
  final String paymentStatus;
  final String shippingName;
  final String shippingPhone;
  final String shippingAddress;
  final String? shippingNotes;
  final double? shippingLatitude;
  final double? shippingLongitude;
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
  final double? driverLatitude;
  final double? driverLongitude;
  final String? trackingStatus;
  final String? trackingUrl;
  final List<Map<String, dynamic>> trackingHistory;
  final List<Map<String, dynamic>> driverMessages;
  final List<OrderItemModel> items;
  final OrderPaymentModel? payment;

  OrderDetailModel({
    required this.id,
    this.storeId,
    this.storeName,
    this.storeAddress,
    this.storeLatitude,
    this.storeLongitude,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    this.subtotal = 0,
    this.shippingCost = 0,
    required this.paymentStatus,
    required this.shippingName,
    required this.shippingPhone,
    required this.shippingAddress,
    this.shippingNotes,
    this.shippingLatitude,
    this.shippingLongitude,
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
    this.driverLatitude,
    this.driverLongitude,
    this.trackingStatus,
    this.trackingUrl,
    this.trackingHistory = const [],
    this.driverMessages = const [],
    required this.items,
    required this.payment,
  });

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    final storeMap = json['store'] is Map<String, dynamic>
        ? json['store'] as Map<String, dynamic>
        : null;

    final rawHistory = json['tracking_history'];
    final historyList = rawHistory is List
        ? rawHistory
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    final rawMessages = json['driver_messages'];
    final messagesList = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    return OrderDetailModel(
      id: json['id'],
      storeId: json['store_id']?.toString() ?? storeMap?['id']?.toString(),
      storeName: storeMap?['name']?.toString(),
      storeAddress: storeMap?['address']?.toString(),
      storeLatitude: (storeMap?['latitude'] as num?)?.toDouble(),
      storeLongitude: (storeMap?['longitude'] as num?)?.toDouble(),
      orderNumber: json['order_number'],
      status: json['status'],
      totalAmount: (json['total_amount'] as num).toInt(),
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      shippingCost: (json['shipping_cost'] as num?)?.toInt() ?? 0,
      paymentStatus: json['payment_status'],
      shippingName: json['shipping_name'] ?? '',
      shippingPhone: json['shipping_phone'] ?? '',
      shippingAddress: json['shipping_address'] ?? '',
      shippingNotes: json['shipping_notes'],
      shippingLatitude: (json['shipping_latitude'] as num?)?.toDouble(),
      shippingLongitude: (json['shipping_longitude'] as num?)?.toDouble(),
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
      driverLatitude: (json['driver_latitude'] as num?)?.toDouble(),
      driverLongitude: (json['driver_longitude'] as num?)?.toDouble(),
      trackingStatus: json['tracking_status'],
      trackingUrl: json['tracking_url']?.toString(),
      trackingHistory: historyList,
      driverMessages: messagesList,
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
      courierServiceType == 'same_day' ||
      (courierCode?.toLowerCase().contains('gojek') ?? false) ||
      (courierCode?.toLowerCase().contains('grab') ?? false) ||
      (courierCode?.toLowerCase().contains('ojek') ?? false) ||
      (courierName?.toLowerCase().contains('gojek') ?? false) ||
      (courierName?.toLowerCase().contains('ojek') ?? false);

  double get effectiveStoreLat => storeLatitude ?? -6.303112;
  double get effectiveStoreLng => storeLongitude ?? 106.779493;
  double get effectiveDestLat => shippingLatitude ?? -6.244179;
  double get effectiveDestLng => shippingLongitude ?? 106.783529;

  double get gpsProgressFraction {
    if (status == 'completed') return 1.0;
    final st = (trackingStatus ?? '').toLowerCase();
    switch (st) {
      case 'allocated':
        return 0.20;
      case 'picking_up':
        return 0.35;
      case 'picked':
        return 0.50;
      case 'dropping_off':
      case 'on_delivery':
      case 'in_transit':
        return 0.78;
      case 'delivered':
        return 1.0;
      default:
        return status == 'shipped' ? 0.65 : 0.10;
    }
  }

  double get effectiveDriverLat {
    if (driverLatitude != null) return driverLatitude!;
    final t = gpsProgressFraction;
    return effectiveStoreLat + (effectiveDestLat - effectiveStoreLat) * t;
  }

  double get effectiveDriverLng {
    if (driverLongitude != null) return driverLongitude!;
    final t = gpsProgressFraction;
    return effectiveStoreLng + (effectiveDestLng - effectiveStoreLng) * t;
  }

  double get estimatedDistanceKm {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(effectiveDestLat - effectiveStoreLat);
    final dLng = _degToRad(effectiveDestLng - effectiveStoreLng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(effectiveStoreLat)) *
            math.cos(_degToRad(effectiveDestLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
}
