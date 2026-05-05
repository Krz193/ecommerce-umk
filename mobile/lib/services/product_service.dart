import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

class ProductService {
  final supabase = Supabase.instance.client;

  Future<List<Product>> getProducts() async {
    final data = await supabase
      .from('products')
      .select()
      .order('created_at');

    return (data as List)
      .map((item) => Product.fromMap(item))
      .toList();
  }
}