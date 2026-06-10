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
    }
  }
}
