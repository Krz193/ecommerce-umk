import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/products/providers/product_detail_provider.dart';
import 'package:mobile/features/cart/services/cart_service.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';

class ProductDetailPage extends ConsumerWidget {
  final String productId;
  static final cartService = CartService();

  const ProductDetailPage({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Detail')),

      body: ref
          .watch(productDetailProvider(productId))
          .when(
            data: (product) {
              return Padding(
                padding: const EdgeInsets.all(24),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      product.name,

                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Rp ${product.price}',

                      style: const TextStyle(fontSize: 20),
                    ),

                    const SizedBox(height: 12),

                    Text('Stock: ${product.stock}'),

                    const SizedBox(height: 24),

                    Text(product.description ?? 'No description'),

                    const Spacer(),
                    SizedBox(
                      width: double.infinity,

                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await cartService.addToCart(
                              productId: product.id,

                              storeId: product.storeId,
                            );

                            ref.invalidate(cartProvider);

                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to cart')),
                            );
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        },

                        child: const Text('Add To Cart'),
                      ),
                    ),
                  ],
                ),
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
