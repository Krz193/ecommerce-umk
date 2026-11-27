import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/cart/models/cart_item_model.dart';
import 'package:mobile/features/cart/models/cart_model.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/features/cart/services/cart_service.dart';
import 'package:mobile/features/checkout/checkout_page.dart';
import 'package:mobile/features/flash_sale/models/sale_event_model.dart';
import 'package:mobile/features/flash_sale/providers/flash_sale_provider.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});
  static final cartService = CartService();

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  final Set<String> _busyItemIds = <String>{};
  final Map<String, int> _optimisticQuantities = <String, int>{};

  int _effectiveQty(CartItemModel item) {
    return _optimisticQuantities[item.id] ?? item.quantity;
  }

  Future<void> _updateQuantityOptimistic(
    CartItemModel item,
    int nextQty,
  ) async {
    if (_busyItemIds.contains(item.id)) return;
    if (nextQty > item.productStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok tidak mencukupi (tersisa ${item.productStock})'),
        ),
      );
      return;
    }

    setState(() {
      _busyItemIds.add(item.id);
      _optimisticQuantities[item.id] = nextQty;
    });

    try {
      await CartPage.cartService.updateCartQuantity(
        cartItemId: item.id,
        quantity: nextQty,
      );
      await ref.refresh(cartProvider.future).then((_) {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyItemIds.remove(item.id);
          _optimisticQuantities.remove(item.id);
        });
      }
    }
  }

  Future<void> _showQuantityPickerDialog(CartItemModel item) async {
    if (item.productStock <= 0) return;
    final controller = TextEditingController(text: '${_effectiveQty(item)}');
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ubah Jumlah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Jumlah (maks ${item.productStock})',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0) {
                Navigator.of(dialogContext).pop(0);
                return;
              }
              final clamped = parsed > item.productStock
                  ? item.productStock
                  : parsed;
              Navigator.of(dialogContext).pop(clamped);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (picked != null && mounted && picked != _effectiveQty(item)) {
      await _updateQuantityOptimistic(item, picked);
    }
  }

  Future<void> _runItemAction(
    String itemId,
    Future<void> Function() action,
  ) async {
    if (_busyItemIds.contains(itemId)) return;
    setState(() {
      _busyItemIds.add(itemId);
    });
    try {
      await action();
      ref.invalidate(cartProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyItemIds.remove(itemId);
        });
      }
    }
  }

  int _computeCartTotal(
    CartModel cart,
    Map<String, ProductFlashSaleInfo> flashSales,
  ) {
    return cart.items.fold<int>(0, (sum, item) {
      final qty = _effectiveQty(item);
      if (qty <= 0) return sum;
      final split = flashSales[item.productId]?.splitForQuantity(
        qty,
        fallbackRegularPrice: item.productPrice,
      );
      return sum + (split?.totalSubtotal ?? (item.productPrice * qty));
    });
  }

  @override
  Widget build(BuildContext context) {
    final flashSales =
        ref.watch(cartFlashSalesProvider).asData?.value ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: ref.watch(cartProvider).when(
        data: (carts) {
          final nonEmptyCarts =
              carts.where((c) => c.items.isNotEmpty).toList();

          if (nonEmptyCarts.isEmpty) {
            return const Center(child: Text('Cart is empty'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: nonEmptyCarts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, cartIndex) {
              final cart = nonEmptyCarts[cartIndex];
              final cartTotal = _computeCartTotal(cart, flashSales);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Toko #${cartIndex + 1}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${cart.totalItems} item',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    ...List.generate(cart.items.length, (itemIndex) {
                      final item = cart.items[itemIndex];
                      return Column(
                        children: [
                          if (itemIndex > 0) const Divider(height: 24),
                          _buildCartItem(item, flashSales),
                        ],
                      );
                    }),
                    const Divider(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final totalLabel = Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Toko'),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(cartTotal),
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
                                  builder: (_) => CheckoutPage(cartId: cart.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.shopping_cart_checkout),
                            label: const Text('Checkout'),
                          ),
                        );

                        if (constraints.maxWidth < 320) {
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
                                minWidth: 140,
                                maxWidth: 172,
                              ),
                              child: checkoutButton,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
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

  Widget _buildCartItem(
    CartItemModel item,
    Map<String, ProductFlashSaleInfo> flashSales,
  ) {
    final isBusy = _busyItemIds.contains(item.id);
    final qty = _effectiveQty(item);
    final split = flashSales[item.productId]?.splitForQuantity(
      qty,
      fallbackRegularPrice: item.productPrice,
    );
    final itemSubtotal = split?.totalSubtotal ?? (item.productPrice * qty);

    return Column(
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                CurrencyFormatter.format(split.regularPrice),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ] else
          Text(CurrencyFormatter.format(item.productPrice)),
        const SizedBox(height: 8),
        Text(
          item.productStock > 0
              ? 'Available stock: ${item.productStock}'
              : 'Out of stock',
          style: TextStyle(
            color: item.productStock > 0 ? Colors.grey.shade700 : Colors.red,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            IconButton(
              onPressed: isBusy
                  ? null
                  : () => _updateQuantityOptimistic(item, qty - 1),
              icon: const Icon(Icons.remove),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: isBusy ? null : () => _showQuantityPickerDialog(item),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$qty',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(
              onPressed: (isBusy || qty >= item.productStock)
                  ? null
                  : () => _updateQuantityOptimistic(item, qty + 1),
              icon: const Icon(Icons.add),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Remove item',
              onPressed: isBusy
                  ? null
                  : () => _runItemAction(
                      item.id,
                      () => CartPage.cartService.removeCartItem(
                        cartItemId: item.id,
                      ),
                    ),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Subtotal: ${CurrencyFormatter.format(itemSubtotal)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
