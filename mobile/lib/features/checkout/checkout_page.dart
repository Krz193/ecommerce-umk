import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/checkout/providers/checkout_provider.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/address/providers/address_provider.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() =>
      _CheckoutPageState();
}

class _CheckoutPageState
    extends ConsumerState<CheckoutPage> {

  bool isLoading = false;

  Future<void> handleCheckout() async {
    try {
      setState(() {
        isLoading = true;
      });

      final checkoutService =
          ref.read(checkoutServiceProvider);

      final cartState = ref.read(cartProvider);
      final carts = cartState.asData?.value;

      if (carts == null || carts.isEmpty) {
        throw Exception('Cart is empty');
      }

      final cart = carts.first;

      final addresses =
          ref.read(addressProvider).asData?.value;

      final selectedAddress =
          addresses != null && addresses.isNotEmpty
              ? addresses.first
              : null;

      if (selectedAddress == null) {
        throw Exception('No address selected');
      }

      final result = await checkoutService.checkout(
        cartId: cart.id,
        addressId: selectedAddress.id,
      );

      if (!mounted) return;

      debugPrint(result.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'Checkout success',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressState = ref.watch(addressProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            ref.watch(cartProvider).when(
              data: (carts) {
                if (carts.isEmpty) {
                  return const Text('Cart is empty');
                }

                final cart = carts.first;
                final total = cart.subtotal;
                final totalItems = cart.totalItems;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(16),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      // distinct item
                      // Text('Items: ${items.length}'),

                      // quantity
                      Text('Items: $totalItems'),

                      const SizedBox(height: 8),

                      Text('Subtotal: ${CurrencyFormatter.format(total)}'),
                    ],
                  ),
                );
              },

              error: (error, stackTrace) {
                return Text(error.toString());
              },

              loading: () {
                return const CircularProgressIndicator();
              },
            ),

            const SizedBox(height: 24),

            const Text(
              'Shipping Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            addressState.when(
              data: (addresses) {
                if (addresses.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(16),
                      color: Colors.white,
                    ),
                    child: const Text(
                      'No address selected',
                    ),
                  );
                }

                final address = addresses.first;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(16),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        address.recipientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(address.phoneNumber),

                      const SizedBox(height: 8),

                      Text(address.fullAddress),
                    ],
                  ),
                );
              },

              error: (error, stackTrace) {
                return Text(error.toString());
              },

              loading: () {
                return const CircularProgressIndicator();
              },
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    isLoading ? null : handleCheckout,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}