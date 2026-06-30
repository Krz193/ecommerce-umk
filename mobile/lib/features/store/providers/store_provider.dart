import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/product/models/product_model.dart';
import 'package:mobile/features/store/models/store_model.dart';
import 'package:mobile/features/store/services/store_service.dart';

final storeServiceProvider = Provider<StoreService>((ref) {
  return StoreService();
});

final myStoreProvider = FutureProvider.autoDispose<StoreModel?>((ref) async {
  final storeService = ref.read(storeServiceProvider);

  return storeService.getMyStore();
});

final publicStoreProvider = FutureProvider.family<StoreModel, String>((
  ref,
  storeId,
) async {
  final response = await supabase
      .from('stores')
      .select('id, owner_id, name, slug, description, phone, address, status')
      .eq('id', storeId)
      .single();

  return StoreModel.fromMap(response);
});

final publicStoreProductsProvider =
    FutureProvider.family<List<ProductModel>, String>((ref, storeId) async {
      final response = await supabase
          .from('products')
          .select('''
            *,
            category:categories (
              id,
              name,
              slug
            ),
            product_images (
              id,
              product_id,
              image_url,
              sort_order
            )
          ''')
          .eq('store_id', storeId)
          .eq('status', 'published')
          .order('created_at', ascending: false);

      return response
          .map<ProductModel>((json) => ProductModel.fromJson(json))
          .toList();
    });
