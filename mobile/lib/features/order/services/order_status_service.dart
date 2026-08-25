import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/order/models/order_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderStatusException implements Exception {
  final String message;

  OrderStatusException(this.message);

  @override
  String toString() => message;
}

class OrderStatusService {
  final SupabaseClient _supabase = supabase;

  Future<OrderModel> shipOrder({
    required String orderId,
    required String shippingProvider,
    required String trackingNumber,
    String? driverName,
    String? driverPhone,
  }) {
    return updateOrderStatus(
      orderId: orderId,
      status: 'shipped',
      shippingProvider: shippingProvider,
      trackingNumber: trackingNumber,
      driverName: driverName,
      driverPhone: driverPhone,
    );
  }

  Future<OrderModel> confirmReceived({required String orderId}) {
    return updateOrderStatus(orderId: orderId, status: 'completed');
  }

  Future<OrderModel> updateOrderStatus({
    required String orderId,
    required String status,
    String? shippingProvider,
    String? trackingNumber,
    String? driverName,
    String? driverPhone,
  }) async {
    final body = <String, dynamic>{
      'order_id': orderId,
      'status': status,
      'shipping_provider': ?shippingProvider,
      'tracking_number': ?trackingNumber,
      'driver_name': ?driverName,
      'driver_phone': ?driverPhone,
    };

    final response = await _supabase.functions.invoke(
      'update-order-status',
      body: body,
    );

    if (response.status != 200) {
      final data = response.data;

      if (data is Map && data['error'] != null) {
        throw OrderStatusException(data['error'].toString());
      }

      throw OrderStatusException('Failed to update order status');
    }

    final data = response.data;

    if (data is! Map || data['order'] == null) {
      throw OrderStatusException('Failed to read updated order');
    }

    return OrderModel.fromJson(Map<String, dynamic>.from(data['order']));
  }
}
