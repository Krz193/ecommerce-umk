import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/product/models/product_model.dart';
import 'package:mobile/features/product/models/stock_movement_model.dart';
import 'package:mobile/features/product/services/seller_product_service.dart';

final sellerProductServiceProvider = Provider<SellerProductService>((ref) {
  return SellerProductService();
});

final sellerProductsProvider = FutureProvider.autoDispose
    .family<List<ProductModel>, String>((ref, storeId) async {
      final sellerProductService = ref.read(sellerProductServiceProvider);

      return sellerProductService.getProducts(storeId: storeId);
    });

final productStockMovementsProvider = FutureProvider.autoDispose
    .family<List<StockMovementModel>, String>((ref, productId) async {
      final sellerProductService = ref.read(sellerProductServiceProvider);

      return sellerProductService.getStockMovements(productId: productId);
    });
