import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/assistant/models/store_content_model.dart';

final publicStoreContentsProvider = FutureProvider.autoDispose
    .family<List<StoreContentModel>, String?>((ref, contentType) async {
      var query = supabase
          .from('store_contents')
          .select('''
        *,
        stores (
          name,
          logo_url,
          address
        ),
        products (
          id,
          name,
          price,
          thumbnail_url
        )
      ''')
          .eq('is_active', true);

      if (contentType != null &&
          contentType.isNotEmpty &&
          contentType != 'all') {
        query = query.eq('content_type', contentType);
      }

      final response = await query.order('created_at', ascending: false);
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => StoreContentModel.fromMap(json)).toList();
    });

final publicHomeBannersProvider =
    FutureProvider.autoDispose<List<StoreContentModel>>((ref) async {
      final response = await supabase
          .from('store_contents')
          .select('''
        *,
        stores (
          name,
          logo_url
        ),
        products (
          id,
          name,
          price,
          thumbnail_url
        )
      ''')
          .eq('is_active', true)
          .inFilter('content_type', ['banner', 'promo'])
          .order('created_at', ascending: false)
          .limit(5);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => StoreContentModel.fromMap(json)).toList();
    });

final storePublicContentsProvider = FutureProvider.autoDispose
    .family<List<StoreContentModel>, String>((ref, storeId) async {
      final response = await supabase
          .from('store_contents')
          .select('''
        *,
        stores (
          name,
          logo_url
        ),
        products (
          id,
          name,
          price,
          thumbnail_url
        )
      ''')
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => StoreContentModel.fromMap(json)).toList();
    });
