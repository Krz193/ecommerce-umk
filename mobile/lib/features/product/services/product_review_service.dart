import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/product/models/product_review_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductReviewException implements Exception {
  final String message;

  ProductReviewException(this.message);

  @override
  String toString() => message;
}

class ProductReviewService {
  final SupabaseClient _supabase = supabase;

  /// Fetch all approved reviews for a given product
  Future<List<ProductReviewModel>> fetchProductReviews(String productId) async {
    try {
      final response = await _supabase
          .from('product_reviews')
          .select('''
            *,
            users:user_id (
              full_name,
              avatar_url
            )
          ''')
          .eq('product_id', productId)
          .eq('is_approved', true)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((json) => ProductReviewModel.fromJson(json))
          .toList();

      return list;
    } catch (e) {
      throw ProductReviewException('Gagal mengambil ulasan produk: $e');
    }
  }

  /// Check existing user review for a specific product and order
  Future<ProductReviewModel?> fetchUserReviewForOrderProduct({
    required String productId,
    required String orderId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('product_reviews')
          .select('''
            *,
            users:user_id (
              full_name,
              avatar_url
            )
          ''')
          .eq('product_id', productId)
          .eq('order_id', orderId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return ProductReviewModel.fromJson(response);
    } catch (e) {
      throw ProductReviewException('Gagal mengecek ulasan pengguna: $e');
    }
  }

  /// Create a new review for a product from a delivered order
  Future<ProductReviewModel> createReview({
    required String productId,
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw ProductReviewException('Pengguna belum login.');
    }

    try {
      final response = await _supabase
          .from('product_reviews')
          .insert({
            'product_id': productId,
            'order_id': orderId,
            'user_id': user.id,
            'rating': rating,
            'comment': comment?.trim().isEmpty == true ? null : comment?.trim(),
          })
          .select('''
            *,
            users:user_id (
              full_name,
              avatar_url
            )
          ''')
          .single();

      return ProductReviewModel.fromJson(response);
    } catch (e) {
      throw ProductReviewException('Gagal membuat ulasan: $e');
    }
  }

  /// Update an existing review
  Future<ProductReviewModel> updateReview({
    required String reviewId,
    required int rating,
    String? comment,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw ProductReviewException('Pengguna belum login.');
    }

    try {
      final response = await _supabase
          .from('product_reviews')
          .update({
            'rating': rating,
            'comment': comment?.trim().isEmpty == true ? null : comment?.trim(),
          })
          .eq('id', reviewId)
          .eq('user_id', user.id)
          .select('''
            *,
            users:user_id (
              full_name,
              avatar_url
            )
          ''')
          .single();

      return ProductReviewModel.fromJson(response);
    } catch (e) {
      throw ProductReviewException('Gagal memperbarui ulasan: $e');
    }
  }

  /// Delete a review
  Future<void> deleteReview(String reviewId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw ProductReviewException('Pengguna belum login.');
    }

    try {
      await _supabase
          .from('product_reviews')
          .delete()
          .eq('id', reviewId)
          .eq('user_id', user.id);
    } catch (e) {
      throw ProductReviewException('Gagal menghapus ulasan: $e');
    }
  }

  /// Seller reply to a review
  Future<ProductReviewModel> sellerReplyReview({
    required String reviewId,
    required String sellerReply,
  }) async {
    try {
      final response = await _supabase
          .from('product_reviews')
          .update({
            'seller_reply': sellerReply.trim(),
            'seller_replied_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reviewId)
          .select('''
            *,
            users:user_id (
              full_name,
              avatar_url
            )
          ''')
          .single();

      return ProductReviewModel.fromJson(response);
    } catch (e) {
      throw ProductReviewException('Gagal memberikan balasan ulasan: $e');
    }
  }

  /// Toggle review approval (hide/show review) by Seller
  Future<ProductReviewModel> toggleReviewApproval({
    required String reviewId,
    required bool isApproved,
  }) async {
    try {
      final response = await _supabase
          .from('product_reviews')
          .update({'is_approved': isApproved})
          .eq('id', reviewId)
          .select('''
            *,
            users:user_id (
              full_name,
              avatar_url
            )
          ''')
          .single();

      return ProductReviewModel.fromJson(response);
    } catch (e) {
      throw ProductReviewException('Gagal mengubah status ulasan: $e');
    }
  }
}
