import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/features/flash_sale/models/sale_event_model.dart';
import 'package:mobile/features/flash_sale/services/flash_sale_service.dart';

final flashSaleServiceProvider = Provider<FlashSaleService>((ref) {
  return FlashSaleService();
});

final publicSaleEventsProvider = FutureProvider.autoDispose<List<SaleEventModel>>(
  (ref) async {
    final service = ref.read(flashSaleServiceProvider);
    return service.getPublicSaleEvents();
  },
);

final productFlashSaleProvider = FutureProvider.autoDispose
    .family<ProductFlashSaleInfo?, String>((ref, productId) async {
      final service = ref.read(flashSaleServiceProvider);
      final map = await service.getActiveProductFlashSales([productId]);
      return map[productId];
    });

final cartFlashSalesProvider =
    FutureProvider.autoDispose<Map<String, ProductFlashSaleInfo>>((ref) async {
      final carts = await ref.watch(cartProvider.future);
      final productIds = carts
          .expand((c) => c.items)
          .map((item) => item.productId)
          .toSet()
          .toList();

      if (productIds.isEmpty) {
        return {};
      }

      final service = ref.read(flashSaleServiceProvider);
      return service.getActiveProductFlashSales(productIds);
    });

final sellerSaleEventsProvider = FutureProvider.autoDispose
    .family<List<SaleEventModel>, String>((ref, storeId) async {
      final service = ref.read(flashSaleServiceProvider);
      return service.getSellerManageableEvents(storeId);
    });
