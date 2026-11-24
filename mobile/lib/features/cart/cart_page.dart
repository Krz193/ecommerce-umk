import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/features/cart/services/cart_service.dart';
import 'package:mobile/features/checkout/checkout_page.dart';
import 'package:mobile/features/flash_sale/providers/flash_sale_provider.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});
  static final cartService = CartService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flashSales = ref.watch(cartFlashSalesProvider).asData?.value ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),

      bottomNavigationBar: ref
          .watch(cartProvider)
          .maybeWhen(
            data: (carts) {
              if (carts.isEmpty || carts.first.items.isEmpty) {
                return null;
              }

              final total = carts.first.items.fold<int>(0, (sum, item) {
                final split = flashSales[item.productId]?.splitForQuantity(
                  item.quantity,
                  fallbackRegularPrice: item.productPrice,
                );
                return sum + (split?.totalSubtotal ?? item.subtotal);
              });

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
                        final split = flashSales[item.productId]
                            ?.splitForQuantity(
                              item.quantity,
                              fallbackRegularPrice: item.productPrice,
                            );
                        final itemSubtotal =
                            split?.totalSubtotal ?? item.subtotal;

                        return Container(
                          padding: const EdgeInsets.all(16),

                          decoration: BoxDecoration(
                            color: Colors.white,

                            borderRadius: BorderRadius.circular(16),
                          ),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              if (item.productThumbnail != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    item.productThumbnail!,
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 140,
                                        color: Colors.grey.shade200,
                                        alignment: Alignment.center,
                                        child: const Text('Image unavailable'),
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(height: 12),
                              ],

                              Text(
                                item.productName,

                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 8),

                              if (split != null && split.isSplit) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.primary.withAlpha(80),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '⚡ ${split.saleQty} pcs × ${CurrencyFormatter.format(split.salePrice)} (Harga Flash Sale)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryHover,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '🏷️ ${split.regularQty} pcs × ${CurrencyFormatter.format(split.regularPrice)} (Harga Normal — Melewati sisa kuota/batas beli promo)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (split != null && split.hasFlashSale) ...[
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '⚡ Flash Sale',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyFormatter.format(split.salePrice),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryHover,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      CurrencyFormatter.format(
                                        split.regularPrice,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else
                                Text(
                                  CurrencyFormatter.format(item.productPrice),
                                ),

                              const SizedBox(height: 8),

                              Text(
                                item.productStock > 0
                                    ? 'Available stock: ${item.productStock}'
                                    : 'Out of stock',
                                style: TextStyle(
                                  color: item.productStock > 0
                                      ? Colors.grey.shade700
                                      : Colors.red,
                                ),
                              ),

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
                                    onPressed:
                                        item.quantity >= item.productStock
                                        ? null
                                        : () async {
                                            await cartService
                                                .updateCartQuantity(
                                                  cartItemId: item.id,

                                                  quantity: item.quantity + 1,
                                                );

                                            ref.invalidate(cartProvider);
                                          },

                                    icon: const Icon(Icons.add),
                                  ),

                                  const Spacer(),

                                  IconButton(
                                    tooltip: 'Remove item',
                                    onPressed: () async {
                                      await cartService.removeCartItem(
                                        cartItemId: item.id,
                                      );

                                      ref.invalidate(cartProvider);
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Text(
                                'Subtotal: ${CurrencyFormatter.format(itemSubtotal)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
