import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/models/product_recommendation_model.dart';

final productRecommendationsProvider = FutureProvider<List<ProductRecommendationModel>>((ref) async {
  final response = await supabase
      .from('product_recommendations')
      .select('''
        *,
        product:products (
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
        )
      ''')
      .eq('is_active', true)
      .order('priority', ascending: false)
      .order('created_at', ascending: false)
      .limit(10);
      
  return response
      .map((json) => ProductRecommendationModel.fromJson(json))
      .toList();
});
