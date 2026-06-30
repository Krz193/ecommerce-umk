import 'dart:typed_data';

import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/product/models/product_image_model.dart';
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
    required String categoryId,
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
            'category_id': categoryId,
            'description': description,
            'status': 'draft',
          })
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
    required String categoryId,
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
            'category_id': categoryId,
            'description': description,
            'status': status,
          })
          .eq('id', productId)
          .eq('store_id', storeId)
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
    if (status == 'published') {
      final product = await _supabase
          .from('products')
          .select('''
            thumbnail_url,
            category_id,
            product_images (
              image_url
            )
          ''')
          .eq('id', productId)
          .eq('store_id', storeId)
          .single();

      final thumbnailUrl = product['thumbnail_url'];
      final categoryId = product['category_id'];
      final images = product['product_images'];
      final hasMatchingThumbnail =
          thumbnailUrl != null &&
          images is List &&
          images.any((image) => image['image_url'] == thumbnailUrl);

      if (!hasMatchingThumbnail) {
        throw SellerProductException(
          'Choose a product thumbnail before publishing',
        );
      }

      if (categoryId == null) {
        throw SellerProductException(
          'Choose a product category before publishing',
        );
      }
    }

    try {
      final response = await _supabase
          .from('products')
          .update({'status': status})
          .eq('id', productId)
          .eq('store_id', storeId)
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

  Future<ProductModel> updateProductStock({
    required String productId,
    required String storeId,
    required int stock,
  }) async {
    if (stock < 0) {
      throw SellerProductException('Stock cannot be below zero');
    }

    try {
      final response = await _supabase
          .from('products')
          .update({'stock': stock})
          .eq('id', productId)
          .eq('store_id', storeId)
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

  Future<ProductImageModel> addProductImage({
    required String productId,
    required String storeId,
    required Uint8List bytes,
    required String extension,
    required int sortOrder,
  }) async {
    final safeExtension = extension.toLowerCase() == 'png'
        ? 'png'
        : extension.toLowerCase() == 'webp'
        ? 'webp'
        : 'jpg';

    final path =
        'products/$productId/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    final contentType = switch (safeExtension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    try {
      await _supabase.storage
          .from('product-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      final imageUrl = _supabase.storage
          .from('product-images')
          .getPublicUrl(path);

      final response = await _supabase
          .from('product_images')
          .insert({
            'product_id': productId,
            'image_url': imageUrl,
            'sort_order': sortOrder,
          })
          .select()
          .single();

      return ProductImageModel.fromJson(response);
    } on StorageException catch (error) {
      throw SellerProductException(error.message);
    } on PostgrestException catch (error) {
      throw SellerProductException(error.message);
    }
  }

  Future<ProductModel> setProductThumbnail({
    required String productId,
    required String imageId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'set_product_thumbnail',
        params: {'product_uuid': productId, 'image_uuid': imageId},
      );

      return ProductModel.fromJson(response);
    } on PostgrestException catch (error) {
      throw SellerProductException(error.message);
    }
  }

  Future<void> deleteProductImage({
    required String productId,
    required String imageId,
  }) async {
    try {
      final product = await _supabase
          .from('products')
          .select('thumbnail_url')
          .eq('id', productId)
          .single();

      final image = await _supabase
          .from('product_images')
          .select('image_url')
          .eq('id', imageId)
          .eq('product_id', productId)
          .single();

      await _supabase
          .from('product_images')
          .delete()
          .eq('id', imageId)
          .eq('product_id', productId);

      if (product['thumbnail_url'] == image['image_url']) {
        await _supabase
            .from('products')
            .update({'thumbnail_url': null})
            .eq('id', productId);
      }
    } on PostgrestException catch (error) {
      throw SellerProductException(error.message);
    }
  }
}
