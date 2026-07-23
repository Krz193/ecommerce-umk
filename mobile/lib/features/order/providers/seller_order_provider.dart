import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/order/models/order_detail_model.dart';
import 'package:mobile/features/order/models/order_model.dart';
import 'package:mobile/features/order/services/seller_order_service.dart';

final sellerOrderServiceProvider = Provider<SellerOrderService>((ref) {
  return SellerOrderService();
});

final sellerOrdersProvider = FutureProvider.autoDispose
    .family<List<OrderModel>, String>((ref, storeId) async {
      final sellerOrderService = ref.read(sellerOrderServiceProvider);

      return sellerOrderService.getOrders(storeId: storeId);
    });

final sellerOrderDetailProvider = FutureProvider.autoDispose
    .family<OrderDetailModel, SellerOrderDetailParams>((ref, params) async {
      final sellerOrderService = ref.read(sellerOrderServiceProvider);

      return sellerOrderService.getOrderDetail(
        storeId: params.storeId,
        orderId: params.orderId,
      );
    });

class SellerOrderDetailParams {
  final String storeId;
  final String orderId;

  const SellerOrderDetailParams({required this.storeId, required this.orderId});

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SellerOrderDetailParams &&
            runtimeType == other.runtimeType &&
            storeId == other.storeId &&
            orderId == other.orderId;
  }

  @override
  int get hashCode => Object.hash(storeId, orderId);
}
