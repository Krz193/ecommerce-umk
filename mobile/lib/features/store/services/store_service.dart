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
}
