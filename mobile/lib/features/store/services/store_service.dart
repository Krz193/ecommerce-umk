import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/store/models/store_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreException implements Exception {
  final String message;

  StoreException(this.message);

  @override
  String toString() => message;
}

class StoreService {
  final SupabaseClient _supabase = supabase;

  Future<StoreModel?> getMyStore() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final response = await _supabase
        .from('stores')
        .select('id, owner_id, name, slug, description, phone, address, status')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return StoreModel.fromMap(response);
  }

  Future<StoreModel?> getStoreById(String storeId) async {
    final response = await _supabase
        .from('stores')
        .select('id, owner_id, name, slug, description, phone, address, status')
        .eq('id', storeId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return StoreModel.fromMap(response);
  }

  Future<StoreModel> updateStore({
    required String storeId,
    required String name,
    String? description,
    String? phone,
    String? address,
  }) async {
    final response = await _supabase
        .from('stores')
        .update({
          'name': name,
          'description': description,
          'phone': phone,
          'address': address,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', storeId)
        .select('id, owner_id, name, slug, description, phone, address, status')
        .single();

    return StoreModel.fromMap(response);
  }

  Future<StoreModel> createStore({
    required String name,
    required String slug,
    String? description,
    String? phone,
    String? address,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      final response = await _supabase
          .from('stores')
          .insert({
            'owner_id': user.id,
            'name': name,
            'slug': slug,
            'description': description,
            'phone': phone,
            'address': address,
            'status': 'pending',
          })
          .select(
            'id, owner_id, name, slug, description, phone, address, status',
          )
          .single();

      return StoreModel.fromMap(response);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        if (error.message.contains('stores_slug_key')) {
          throw StoreException('Store name is already used');
        }

        if (error.message.contains('stores_owner_unique')) {
          throw StoreException('Your account already has a store');
        }
      }

      if (error.code == '42501') {
        throw StoreException(
          'Your account cannot create this store. Check your seller status or existing store.',
        );
      }

      throw StoreException(error.message);
    } catch (e) {
      throw StoreException('Terjadi kesalahan yang tidak terduga.');
    }
  }

  Future<Map<String, dynamic>> getSellerCartInsights(String storeId) async {
    try {
      final response = await _supabase.rpc(
        'get_seller_cart_insights',
        params: {'p_store_id': storeId},
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw StoreException('Gagal mengambil insight keranjang: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getStoreRecommendationMetrics(
    String storeId,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_store_product_recommendation_metrics',
        params: {'p_store_id': storeId},
      );
      final list = response as List<dynamic>;
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (_) {
      final products = await _supabase
          .from('products')
          .select('''
            id,
            name,
            price,
            original_price,
            discount_percent,
            discount_amount,
            stock,
            status,
            thumbnail_url,
            product_recommendations (
              id,
              priority,
              badge_text,
              is_active,
              formula_score,
              formula_mode
            )
          ''')
          .eq('store_id', storeId)
          .order('created_at', ascending: false);

      return (products as List<dynamic>).map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final recRaw = map['product_recommendations'];
        final rec = recRaw is List && recRaw.isNotEmpty
            ? Map<String, dynamic>.from(recRaw.first as Map)
            : (recRaw is Map ? Map<String, dynamic>.from(recRaw) : null);
        return {
          'product_id': map['id'],
          'product_name': map['name'],
          'price': map['price'],
          'original_price': map['original_price'] ?? map['price'],
          'discount_percent': map['discount_percent'] ?? 0,
          'discount_amount': map['discount_amount'] ?? 0,
          'stock': map['stock'] ?? 0,
          'status': map['status'] ?? 'draft',
          'thumbnail_url': map['thumbnail_url'],
          'sold_qty': 0,
          'avg_rating': 0,
          'review_count': 0,
          'cart_qty': 0,
          'recommendation_id': rec?['id'],
          'is_recommended': rec != null && (rec['is_active'] ?? true) == true,
          'priority': rec?['priority'] ?? 0,
          'badge_text': rec?['badge_text'],
          'formula_score': rec?['formula_score'] ?? 0,
          'formula_mode': rec?['formula_mode'] ?? 'manual',
        };
      }).toList();
    }
  }

  Future<void> saveProductRecommendation({
    required String productId,
    required int priority,
    String? badgeText,
    required bool isActive,
    double formulaScore = 0,
    String formulaMode = 'formula',
    Map<String, dynamic>? formulaBreakdown,
  }) async {
    await _supabase.from('product_recommendations').upsert(
      {
        'product_id': productId,
        'priority': priority,
        'badge_text': badgeText,
        'is_active': isActive,
        'formula_score': formulaScore,
        'formula_mode': formulaMode,
        'formula_breakdown': formulaBreakdown ?? {},
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'product_id',
    );
  }

  Future<void> removeProductRecommendation(String productId) async {
    await _supabase
        .from('product_recommendations')
        .delete()
        .eq('product_id', productId);
  }
}
