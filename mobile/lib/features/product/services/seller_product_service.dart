import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/product/models/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerProductException implements Exception {
  final String message;

  SellerProductException(this.message);

  @override
  String toString() => message;
}

class SellerProductService {
  final SupabaseClient _supabase = supabase;

  Future<List<ProductModel>> getProducts({required String storeId}) async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('store_id', storeId)
        .order('created_at', ascending: false);

    return response
        .map<ProductModel>((json) => ProductModel.fromJson(json))
        .toList();
  }

  Future<ProductModel> createProduct({
    required String storeId,
    required String name,
    required String slug,
    required int price,
    required int stock,
    String? description,
  }) async {
    try {
      final response = await _supabase
          .from('products')
          .insert({
            'store_id': storeId,
            'name': name,
            'slug': slug,
            'price': price,
            'stock': stock,
            'description': description,
            'status': 'draft',
          })
          .select()
          .single();

      return ProductModel.fromJson(response);
    } on PostgrestException catch (error) {
      if (error.code == '23505' &&
          error.message.contains('products_slug_key')) {
        throw SellerProductException('Product name is already used');
      }

      if (error.code == '42501') {
        throw SellerProductException(
          'Your account is not allowed to create products for this store',
        );
      }

      throw SellerProductException(error.message);
    }
  }

  Future<ProductModel> updateProduct({
    required String productId,
    required String storeId,
    required String name,
    required String slug,
    required int price,
    required int stock,
    required String status,
    String? description,
  }) async {
    try {
      final response = await _supabase
          .from('products')
          .update({
            'name': name,
            'slug': slug,
            'price': price,
            'stock': stock,
            'description': description,
            'status': status,
          })
          .eq('id', productId)
          .eq('store_id', storeId)
          .select()
          .single();

      return ProductModel.fromJson(response);
    } on PostgrestException catch (error) {
      if (error.code == '23505' &&
          error.message.contains('products_slug_key')) {
        throw SellerProductException('Product name is already used');
      }

      if (error.code == '42501') {
        throw SellerProductException(
          'Your account is not allowed to update this product',
        );
      }

      throw SellerProductException(error.message);
    }
  }

  Future<ProductModel> updateProductStatus({
    required String productId,
    required String storeId,
    required String status,
  }) async {
    try {
      final response = await _supabase
          .from('products')
          .update({'status': status})
          .eq('id', productId)
          .eq('store_id', storeId)
          .select()
          .single();

      return ProductModel.fromJson(response);
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw SellerProductException(
          'Your account is not allowed to update this product',
        );
      }

      throw SellerProductException(error.message);
    }
  }
}
