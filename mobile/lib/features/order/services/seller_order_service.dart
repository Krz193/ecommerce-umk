import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/utils/error_formatter.dart';
import 'package:mobile/features/order/models/order_detail_model.dart';
import 'package:mobile/features/order/models/order_model.dart';
import 'package:mobile/features/order/services/order_status_service.dart';

class SellerOrderException implements Exception {
  final String message;

  SellerOrderException(this.message);

  @override
  String toString() => message;
}

class SellerOrderService {
  final _supabase = supabase;
  final _orderStatusService = OrderStatusService();

  Future<List<OrderModel>> getOrders({required String storeId}) async {
    final response = await _supabase
        .from('orders')
        .select()
        .eq('store_id', storeId)
        .order('created_at', ascending: false);

    return response
        .map<OrderModel>((json) => OrderModel.fromJson(json))
        .toList();
  }

  Future<OrderDetailModel> getOrderDetail({
    required String storeId,
    required String orderId,
  }) async {
    final response = await _supabase
        .from('orders')
        .select('''
        *,
        store:stores (
          id,
          name,
          slug,
          phone,
          address,
          province,
          city,
          district,
          postal_code,
          notes,
          latitude,
          longitude,
          biteship_area_id
        ),
        payment:payments (
          id,
          status,
          expired_at,
          provider_transaction_id,
          raw_response
        ),
        order_items (
          id,
          product_id,
          product_name,
          product_price,
          quantity,
          subtotal,
          product_thumbnail
        )
        ''')
        .eq('id', orderId)
        .eq('store_id', storeId)
        .maybeSingle();

    if (response == null) {
      throw const ResourceNotFoundException(
        'Pesanan tidak ditemukan atau sudah tidak tersedia untuk toko ini.',
      );
    }

    return OrderDetailModel.fromJson(response);
  }

  Future<OrderModel> shipOrder({
    required String orderId,
    required String shippingProvider,
    String? trackingNumber,
    String? driverName,
    String? driverPhone,
  }) {
    return _orderStatusService.shipOrder(
      orderId: orderId,
      shippingProvider: shippingProvider,
      trackingNumber: trackingNumber,
      driverName: driverName,
      driverPhone: driverPhone,
    );
  }
}
