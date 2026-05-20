import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/products/models/product_model.dart';

final productsProvider =
    FutureProvider<List<ProductModel>>((
      ref,
    ) async {
      final response = await supabase
          .from('products')
          .select()
          .eq('status', 'published');

      return response
          .map<ProductModel>(
            (json) =>
                ProductModel.fromJson(json),
          )
          .toList();
    });