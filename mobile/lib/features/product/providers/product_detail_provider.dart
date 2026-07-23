import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/config/supabase_provider.dart';

import 'package:mobile/features/product/models/product_model.dart';

final productDetailProvider = FutureProvider.family<ProductModel, String>((
  ref,
  productId,
) async {
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
      .eq('id', productId)
      .single();

  return ProductModel.fromJson(response);
});
