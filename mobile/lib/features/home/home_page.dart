import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/product/providers/product_provider.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () {
              context.push('/cart');
            },

            icon: const Icon(Icons.shopping_cart),
          ),
          IconButton(
            onPressed: () async {
              await logout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ref
          .watch(productsProvider)
          .when(
            data: (products) {
              if (products.isEmpty) {
                return const Center(child: Text('No products found'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),

                itemCount: products.length,

                separatorBuilder: (context, index) => const SizedBox(height: 12),

                itemBuilder: (context, index) {
                  final product = products[index];

                  return GestureDetector(
                    onTap: () {
                      context.push('/products/${product.id}');
                    },

                    child: Container(
                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: Colors.white,

                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            product.name,

                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text('Rp ${product.price}'),

                          const SizedBox(height: 4),

                          Text('Stock: ${product.stock}'),
                        ],
                      ),
                    ),
                  );
                },
              );
            },

            error: (error, stackTrace) {
              return Center(child: Text(error.toString()));
            },

            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
          ),
    );
  }
}
