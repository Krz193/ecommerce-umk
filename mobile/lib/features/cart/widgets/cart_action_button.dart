import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/features/cart/providers/cart_provider.dart';

class CartActionButton extends ConsumerWidget {
  const CartActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(
      cartProvider.select(
        (cartState) => cartState.maybeWhen(
          data: (carts) =>
              carts.fold<int>(0, (total, cart) => total + cart.totalItems),
          orElse: () => 0,
        ),
      ),
    );

    final badgeLabel = cartCount > 99 ? '99+' : cartCount.toString();

    return IconButton(
      tooltip: 'Cart',

      onPressed: () {
        context.push('/cart');
      },

      icon: Stack(
        clipBehavior: Clip.none,

        children: [
          const Icon(Icons.shopping_cart_outlined),

          if (cartCount > 0)
            Positioned(
              right: -8,
              top: -8,

              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),

                padding: const EdgeInsets.symmetric(horizontal: 5),

                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(999),
                ),

                alignment: Alignment.center,

                child: Text(
                  badgeLabel,

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
