import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/product/models/product_model.dart';

final productsProvider = FutureProvider<List<ProductModel>>((ref) async {
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
      .eq('status', 'published')
      .order('created_at', ascending: false);

  return response
      .map<ProductModel>((json) => ProductModel.fromJson(json))
      .toList();
});
