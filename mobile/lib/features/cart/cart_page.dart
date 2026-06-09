import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/features/cart/services/cart_service.dart';
import 'package:mobile/features/checkout/checkout_page.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});
  static final cartService = CartService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),

      bottomNavigationBar: ref
          .watch(cartProvider)
          .maybeWhen(
            data: (carts) {
              if (carts.isEmpty || carts.first.items.isEmpty) {
                return null;
              }

              final total = carts.first.items.fold<int>(
                0,
                (total, item) => total + item.subtotal,
              );

              return SafeArea(
                top: false,

                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),

                  decoration: const BoxDecoration(color: Colors.white),

                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalLabel = Column(
                        mainAxisSize: MainAxisSize.min,

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Text('Total'),

                          const SizedBox(height: 4),

                          Text(
                            CurrencyFormatter.format(total),

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );

                      final checkoutButton = SizedBox(
                        height: 48,

                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,

                              MaterialPageRoute(
                                builder: (_) => const CheckoutPage(),
                              ),
                            );
                          },

                          icon: const Icon(Icons.shopping_cart_checkout),

                          label: const Text('Checkout'),
                        ),
                      );

                      if (constraints.maxWidth < 340) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,

                          crossAxisAlignment: CrossAxisAlignment.stretch,

                          children: [
                            totalLabel,

                            const SizedBox(height: 12),

                            checkoutButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: totalLabel),

                          const SizedBox(width: 12),

                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 144,
                              maxWidth: 172,
                            ),

                            child: checkoutButton,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },

            orElse: () => null,
          ),

      body: ref
          .watch(cartProvider)
          .when(
            data: (carts) {
              if (carts.isEmpty) {
                return const Center(child: Text('Cart is empty'));
              }

              final cart = carts.first;
              final items = cart.items;

              if (items.isEmpty) {
                return const Center(child: Text('Cart is empty'));
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),

                      itemCount: items.length,

                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),

                      itemBuilder: (context, index) {
                        final item = items[index];

                        return Container(
                          padding: const EdgeInsets.all(16),

                          decoration: BoxDecoration(
                            color: Colors.white,

                            borderRadius: BorderRadius.circular(16),
                          ),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Text(
                                item.productName,

                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text('Rp ${item.productPrice}'),

                              const SizedBox(height: 12),

                              Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      await cartService.updateCartQuantity(
                                        cartItemId: item.id,

                                        quantity: item.quantity - 1,
                                      );

                                      ref.invalidate(cartProvider);
                                    },

                                    icon: const Icon(Icons.remove),
                                  ),

                                  Text('${item.quantity}'),

                                  IconButton(
                                    onPressed: () async {
                                      await cartService.updateCartQuantity(
                                        cartItemId: item.id,

                                        quantity: item.quantity + 1,
                                      );

                                      ref.invalidate(cartProvider);
                                    },

                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Text('Subtotal: Rp ${item.subtotal}'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
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
