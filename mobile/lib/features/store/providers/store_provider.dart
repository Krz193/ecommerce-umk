import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
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

final storeCartInsightsProvider = FutureProvider.family
    .autoDispose<Map<String, dynamic>, String>((ref, storeId) async {
      final storeService = ref.read(storeServiceProvider);
      return storeService.getSellerCartInsights(storeId);
    });

final storeRecommendationMetricsProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, storeId) async {
      final storeService = ref.read(storeServiceProvider);
      return storeService.getStoreRecommendationMetrics(storeId);
    });

final managedStoreProvider = FutureProvider.autoDispose<StoreModel?>((
  ref,
) async {
  final user = ref.watch(appUserProvider).asData?.value;

  if (user?.isAssistant == true) {
    return ref.watch(handledStoreProvider.future);
  }

  return ref.watch(myStoreProvider.future);
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
      if (storeId.trim().isEmpty) return [];
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
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception(
              'Waktu memuat produk habis. Periksa koneksi internet.',
            ),
          );

      return response
          .map<ProductModel>((json) => ProductModel.fromJson(json))
          .toList();
    });

final publicStoreRecommendedProductsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, storeId) async {
      if (storeId.trim().isEmpty) return [];
      try {
        final response = await supabase
            .from('product_recommendations')
            .select('''
              id,
              badge_text,
              priority,
              is_active,
              product:product_id (
                id,
                store_id,
                name,
                slug,
                price,
                original_price,
                discount_percent,
                discount_amount,
                stock,
                status,
                thumbnail_url
              )
            ''')
            .eq('is_active', true)
            .order('priority', ascending: false)
            .timeout(const Duration(seconds: 10));

        final list = List<Map<String, dynamic>>.from(response as List);
        return list.where((item) {
          final product = item['product'] as Map<String, dynamic>?;
          return product != null &&
              product['store_id'] == storeId &&
              product['status'] == 'published';
        }).toList();
      } catch (_) {
        return [];
      }
    });
