import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/checkout/providers/checkout_provider.dart';
import 'package:mobile/features/cart/providers/cart_provider.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/address/models/address_model.dart';
import 'package:mobile/features/address/providers/address_provider.dart';
import 'package:mobile/features/checkout/models/shipping_rate_model.dart';
import 'package:mobile/features/checkout/providers/shipping_provider.dart';
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
  String selectedFilterCategory = 'all'; // 'all', 'instant', 'regular'
  int selectedDonationAmount = 0; // Voluntary UMK donation (Excel A58)

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
        throw Exception('Keranjang belanja kosong');
      }

      final cart = carts.first;

      if (cart.items.isEmpty) {
        throw Exception('Keranjang belanja kosong');
      }

      for (final item in cart.items) {
        if (item.productStock <= 0) {
          throw Exception('${item.productName} sedang habis stok');
        }

        if (item.quantity > item.productStock) {
          throw Exception(
            '${item.productName} hanya tersisa ${item.productStock} item',
          );
        }
      }

      final addresses = ref.read(addressProvider).asData?.value;
      final selectedAddr = addresses != null
          ? selectedAddress(addresses)
          : null;

      if (selectedAddr == null) {
        throw Exception('Pilih alamat pengiriman terlebih dahulu');
      }

      final selectedCourier = ref.read(selectedShippingRateProvider);
      if (selectedCourier == null) {
        throw Exception(
          'Pilih layanan pengiriman (Ojek / Ekspedisi) terlebih dahulu',
        );
      }

      final shippingCost = selectedCourier.price;
      final grandTotal = cart.subtotal + shippingCost + selectedDonationAmount;

      final confirmed = await confirmCheckout(
        itemCount: cart.totalItems,
        subtotal: cart.subtotal,
        shippingFee: shippingCost,
        grandTotal: grandTotal,
        courier: selectedCourier,
        address: selectedAddr,
      );

      if (!confirmed) {
        return;
      }

      final result = await checkoutService.checkout(
        cartId: cart.id,
        addressId: selectedAddr.id,
        selectedCourier: selectedCourier.toMap(),
      );

      final orderData = result['order'];
      if (orderData != null && orderData['id'] != null) {
        try {
          await supabase.rpc('set_order_shipping_details', params: {
            'p_order_id': orderData['id'],
            'p_courier_name': selectedCourier.displayName,
            'p_courier_code': selectedCourier.courierCode,
            'p_courier_service_code': selectedCourier.courierServiceCode,
            'p_courier_service_type': selectedCourier.serviceType,
            'p_shipping_cost': selectedCourier.price,
          });

          // Record donation if donor opted in (Excel A58)
          if (selectedDonationAmount > 0) {
            final currentUser = supabase.auth.currentUser;
            await supabase.from('donations').insert({
              'user_id': currentUser?.id,
              'store_id': cart.storeId,
              'order_id': orderData['id'],
              'amount': selectedDonationAmount,
              'donor_name': selectedAddr.recipientName,
              'donor_phone': selectedAddr.phoneNumber,
              'note': 'Donasi sukarela saat checkout pesanan',
              'status': 'paid',
            });
          }
        } catch (e) {
          debugPrint('Error saving shipping details/donation: $e');
        }
      }

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
                title: const Text('Pembayaran Menunggu'),
                content: const Text(
                  'Anda masih memiliki tagihan yang belum dibayar. Mengalihkan ke detail pesanan.',
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
    required int subtotal,
    required int shippingFee,
    required int grandTotal,
    required ShippingRateOption courier,
    required AddressModel address,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Pembayaran'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Produk: $itemCount item'),
                Text('Subtotal: ${CurrencyFormatter.format(subtotal)}'),
                Text('Ongkos Kirim: ${CurrencyFormatter.format(shippingFee)}'),
                const Divider(height: 16),
                Text(
                  'Total Bayar: ${CurrencyFormatter.format(grandTotal)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Metode Pengiriman:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${courier.courierName} - ${courier.courierServiceName} (${courier.durationLabel})',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Alamat Tujuan:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(address.recipientName),
                Text(address.phoneNumber),
                Text(address.fullAddress),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Bayar Sekarang'),
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
    if (message.contains('Cart is empty') || message.contains('kosong')) {
      return 'Keranjang belanja Anda kosong';
    }
    if (message.contains('Address not found')) {
      return 'Alamat yang dipilih tidak tersedia';
    }
    if (message.contains('single store')) {
      return 'Checkout saat ini hanya mendukung 1 toko per transaksi';
    }
    if (message.contains('Insufficient stock')) {
      return 'Stok produk tidak mencukupi';
    }
    if (message.contains('pending payment')) {
      return 'Anda masih memiliki pesanan menunggu pembayaran';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final addressState = ref.watch(addressProvider);
    final cartState = ref.watch(cartProvider);
    final selectedCourier = ref.watch(selectedShippingRateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout & Pengiriman')),
      body: cartState.when(
        data: (carts) {
          if (carts.isEmpty) {
            return const Center(child: Text('Keranjang belanja kosong'));
          }

          final cart = carts.first;
          final subtotal = cart.subtotal;
          final totalItems = cart.totalItems;
          final shippingCost = selectedCourier?.price ?? 0;
          final totalAmount = subtotal + shippingCost + selectedDonationAmount;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Order Summary Card
                const Text(
                  'Ringkasan Belanja',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Jumlah Barang ($totalItems item)'),
                          Text(CurrencyFormatter.format(subtotal)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ongkos Kirim'),
                          Text(
                            selectedCourier != null
                                ? CurrencyFormatter.format(shippingCost)
                                : 'Pilih Kurir',
                            style: TextStyle(
                              color: selectedCourier != null
                                  ? Colors.black
                                  : Colors.grey,
                              fontWeight: selectedCourier != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      if (selectedDonationAmount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Donasi Sukarela Toko'),
                            Text(
                              '+ ${CurrencyFormatter.format(selectedDonationAmount)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Pembayaran',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(totalAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Shipping Address Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Alamat Pengiriman',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/addresses'),
                      child: const Text('Kelola Alamat'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                addressState.when(
                  data: (addresses) {
                    if (addresses.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Column(
                          children: [
                            const Text('Belum ada alamat pengiriman'),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () =>
                                  context.push('/addresses/create'),
                              child: const Text('Tambah Alamat'),
                            ),
                          ],
                        ),
                      );
                    }

                    final activeAddr = selectedAddress(addresses);

                    return Column(
                      children: [
                        if (activeAddr != null)
                          buildAddressCard(address: activeAddr),
                        const SizedBox(height: 16),

                        // 3. Shipping Courier Selector
                        buildCourierSelectionSection(
                          cartId: cart.id,
                          addressId: activeAddr?.id,
                        ),
                        const SizedBox(height: 16),

                        // 4. Voluntary UMK Donation Section (Excel A58)
                        buildDonationSection(),
                      ],
                    );
                  },
                  error: (err, _) => Text(err.toString()),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),

                const SizedBox(height: 24),

                // 4. Checkout Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (isLoading || selectedCourier == null)
                        ? null
                        : handleCheckout,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            selectedCourier != null
                                ? 'Bayar ${CurrencyFormatter.format(totalAmount)}'
                                : 'Pilih Pengiriman Dahulu',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
        error: (err, _) => Center(child: Text(err.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget buildAddressCard({required AddressModel address}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address.label?.isNotEmpty == true
                      ? '${address.label} (${address.recipientName})'
                      : address.recipientName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (address.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Utama',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            address.phoneNumber,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            '${address.fullAddress}, ${address.city}, ${address.province}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget buildCourierSelectionSection({
    required String cartId,
    required String? addressId,
  }) {
    if (addressId == null) return const SizedBox.shrink();

    final ratesAsync = ref.watch(
      shippingRatesFamily(
        ShippingRatesParam(cartId: cartId, addressId: addressId),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilihan Kurir & Ekspedisi (Biteship)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: selectedFilterCategory == 'all',
                onSelected: (val) {
                  if (val) setState(() => selectedFilterCategory = 'all');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: const Text('🛵'),
                label: const Text('Ojek Instan'),
                selected: selectedFilterCategory == 'instant',
                onSelected: (val) {
                  if (val) setState(() => selectedFilterCategory = 'instant');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: const Text('📦'),
                label: const Text('Ekspedisi Reguler'),
                selected: selectedFilterCategory == 'regular',
                onSelected: (val) {
                  if (val) setState(() => selectedFilterCategory = 'regular');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ratesAsync.when(
          data: (options) {
            if (options.isEmpty) {
              return const Text(
                'Tidak ada kurir pengiriman tersedia untuk rute ini.',
              );
            }

            final filteredOptions = options.where((opt) {
              if (selectedFilterCategory == 'instant') return opt.isInstant;
              if (selectedFilterCategory == 'regular') return !opt.isInstant;
              return true;
            }).toList();

            final selectedRate = ref.watch(selectedShippingRateProvider);

            // Auto-select first option if none is selected yet
            if (selectedRate == null && filteredOptions.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref
                    .read(selectedShippingRateProvider.notifier)
                    .selectRate(filteredOptions.first);
              });
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredOptions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final option = filteredOptions[index];
                final isSelected =
                    selectedRate?.courierCode == option.courierCode &&
                    selectedRate?.courierServiceCode ==
                        option.courierServiceCode;

                return InkWell(
                  onTap: () {
                    ref
                        .read(selectedShippingRateProvider.notifier)
                        .selectRate(option);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          option.isInstant
                              ? Icons.two_wheeler
                              : Icons.local_shipping,
                          color: option.isInstant ? Colors.green : Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    option.courierName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      option.courierServiceName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                option.description.isNotEmpty
                                    ? option.description
                                    : 'Estimasi tiba ${option.durationLabel}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Estimasi: ${option.durationLabel}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(option.price),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          error: (err, _) => Text('Gagal memuat tarif: $err'),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildDonationSection() {
    final donationOptions = [0, 1000, 2000, 5000, 10000];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedDonationAmount > 0
              ? Colors.green.shade300
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Donasi Sukarela Toko UMK',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Dukung pengembangan produk dan usaha toko UMK lokal ini.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: donationOptions.map((amount) {
              final isSelected = selectedDonationAmount == amount;
              return ChoiceChip(
                label: Text(
                  amount == 0
                      ? 'Tanpa Donasi'
                      : '+ ${CurrencyFormatter.format(amount)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.green.shade900 : Colors.black87,
                  ),
                ),
                selected: isSelected,
                selectedColor: Colors.green.shade100,
                onSelected: (selected) {
                  setState(() {
                    selectedDonationAmount = selected ? amount : 0;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

