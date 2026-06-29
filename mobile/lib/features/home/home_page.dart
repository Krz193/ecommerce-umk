import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/cart/widgets/cart_action_button.dart';
import 'package:mobile/features/product/providers/product_provider.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [const CartActionButton()],
      ),
      body: ref
          .watch(productsProvider)
          .when(
            data: (products) {
              return ListView(
                padding: const EdgeInsets.all(16),

                children: [
                  if (products.isEmpty)
                    const Center(child: Text('No products found')),

                  ...products.map((product) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),

                      child: GestureDetector(
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
                      ),
                    );
                  }),
                ],
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
