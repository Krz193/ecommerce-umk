import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/checkout/providers/checkout_provider.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/address/models/address_model.dart';
import 'package:mobile/features/address/providers/address_provider.dart';
import 'package:mobile/features/payment/payment_page.dart';

import 'package:go_router/go_router.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  bool isLoading = false;
  String? selectedAddressId;

  AddressModel? selectedAddress(List<AddressModel> addresses) {
    if (addresses.isEmpty) {
      return null;
    }

    for (final address in addresses) {
      if (address.id == selectedAddressId) {
        return address;
      }
    }

    for (final address in addresses) {
      if (address.isDefault) {
        return address;
      }
    }

    return addresses.first;
  }

  Future<void> handleCheckout() async {
    try {
      setState(() {
        isLoading = true;
      });

      final checkoutService = ref.read(checkoutServiceProvider);

      final cartState = ref.read(cartProvider);
      final carts = cartState.asData?.value;

      if (carts == null || carts.isEmpty) {
        throw Exception('Your cart is empty');
      }

      final cart = carts.first;

      if (cart.items.isEmpty) {
        throw Exception('Your cart is empty');
      }

      for (final item in cart.items) {
        if (item.productStock <= 0) {
          throw Exception('${item.productName} is out of stock');
        }

        if (item.quantity > item.productStock) {
          throw Exception(
            '${item.productName} only has ${item.productStock} item(s) left',
          );
        }
      }

      final addresses = ref.read(addressProvider).asData?.value;

      final selectedAddress = addresses != null
          ? this.selectedAddress(addresses)
          : null;

      if (selectedAddress == null) {
        throw Exception('Add or select a shipping address before checkout');
      }

      final confirmed = await confirmCheckout(
        itemCount: cart.totalItems,
        total: cart.subtotal,
        address: selectedAddress,
      );

      if (!confirmed) {
        return;
      }

      final result = await checkoutService.checkout(
        cartId: cart.id,
        addressId: selectedAddress.id,
      );

      if (!mounted) return;

      debugPrint(result.toString());

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            order: result['order'],
            payment: result['payment'],
            midtrans: result['midtrans'],
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      if (error is FunctionException) {
        final details = error.details;

        if (details is Map &&
            details['error'].toString().contains('pending payment')) {
          final orderId = details['order_id'];

          await showDialog(
            context: context,

            builder: (context) {
              return AlertDialog(
                title: const Text('Pending Payment'),

                content: const Text(
                  'You still have pending payment. You will be redirected to continue payment.',
                ),

                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },

                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );

          if (!mounted) return;

          context.push('/orders/$orderId');

          return;
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(readableCheckoutError(error))));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<bool> confirmCheckout({
    required int itemCount,
    required int total,
    required AddressModel address,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Checkout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Items: $itemCount'),
              const SizedBox(height: 8),
              Text('Total: ${CurrencyFormatter.format(total)}'),
              const SizedBox(height: 12),
              const Text(
                'Ship to',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(address.recipientName),
              Text(address.phoneNumber),
              Text(address.fullAddress),
              const SizedBox(height: 12),
              const Text(
                'Checkout currently supports products from one store per order.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Review'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Create Payment'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  String readableCheckoutError(Object error) {
    final raw = error is FunctionException ? error.details : error;

    if (raw is Map) {
      final message = raw['error'] ?? raw['message'];

      if (message != null) {
        return readableCheckoutMessage(message.toString());
      }
    }

    return readableCheckoutMessage(
      error.toString().replaceFirst('Exception: ', ''),
    );
  }

  String readableCheckoutMessage(String message) {
    if (message.contains('Cart is empty')) {
      return 'Your cart is empty';
    }

    if (message.contains('Address not found')) {
      return 'The selected address is no longer available';
    }

    if (message.contains('single store')) {
      return 'Checkout only supports one store at a time';
    }

    if (message.contains('Insufficient stock')) {
      return 'Some products no longer have enough stock';
    }

    if (message.contains('pending payment')) {
      return 'You still have a pending payment';
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    final addressState = ref.watch(addressProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            ref
                .watch(cartProvider)
                .when(
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
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: addressState.when(
                data: (addresses) {
                  if (addresses.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('No address selected'),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              context.push('/addresses/create');
                            },
                            child: const Text('Add Address'),
                          ),
                        ],
                      ),
                    );
                  }

                  final activeAddress = selectedAddress(addresses);

                  return ListView.separated(
                    itemCount: addresses.length + 1,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == addresses.length) {
                        return OutlinedButton(
                          onPressed: () {
                            context.push('/addresses');
                          },
                          child: const Text('Manage Addresses'),
                        );
                      }

                      final address = addresses[index];

                      return buildAddressOption(
                        address: address,
                        activeAddressId: activeAddress?.id,
                      );
                    },
                  );
                },

                error: (error, stackTrace) {
                  return Text(error.toString());
                },

                loading: () {
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : handleCheckout,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAddressOption({
    required AddressModel address,
    required String? activeAddressId,
  }) {
    final isSelected = activeAddressId == address.id;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          selectedAddressId = address.id;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          address.label?.isNotEmpty == true
                              ? address.label!
                              : address.recipientName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (address.isDefault)
                        const Text(
                          'Default',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(address.recipientName),
                  const SizedBox(height: 4),
                  Text(address.phoneNumber),
                  const SizedBox(height: 4),
                  Text('${address.city}, ${address.province}'),
                  const SizedBox(height: 4),
                  Text(address.fullAddress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
