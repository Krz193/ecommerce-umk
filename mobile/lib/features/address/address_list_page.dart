import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/features/address/models/address_model.dart';
import 'package:mobile/features/address/providers/address_provider.dart';

class AddressListPage extends ConsumerStatefulWidget {
  const AddressListPage({super.key});

  @override
  ConsumerState<AddressListPage> createState() => _AddressListPageState();
}

class _AddressListPageState extends ConsumerState<AddressListPage> {
  String? updatingAddressId;

  Future<void> setDefault(AddressModel address) async {
    setState(() {
      updatingAddressId = address.id;
    });

    try {
      final service = ref.read(addressServiceProvider);

      await service.setDefaultAddress(address.id);

      ref.invalidate(addressProvider);
    } finally {
      if (mounted) {
        setState(() {
          updatingAddressId = null;
        });
      }
    }
  }

  Future<void> deleteAddress(AddressModel address) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Address'),
          content: const Text('Delete this address?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      updatingAddressId = address.id;
    });

    try {
      final service = ref.read(addressServiceProvider);

      await service.deleteAddress(address.id);

      ref.invalidate(addressProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Address deleted')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          updatingAddressId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressAsync = ref.watch(addressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Addresses')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/addresses/create');
        },
        child: const Icon(Icons.add),
      ),
      body: addressAsync.when(
        data: (addresses) {
          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'No addresses yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.push('/addresses/create');
                      },
                      child: const Text('Add Address'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(addressProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return buildAddressCard(addresses[index]);
              },
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

  Widget buildAddressCard(AddressModel address) {
    final isUpdating = updatingAddressId == address.id;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (address.isDefault) buildDefaultBadge(),
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
          const SizedBox(height: 12),
          Row(
            children: [
              if (!address.isDefault)
                TextButton(
                  onPressed: isUpdating ? null : () => setDefault(address),
                  child: const Text('Set Default'),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Edit address',
                onPressed: isUpdating
                    ? null
                    : () {
                        context.push('/addresses/${address.id}/edit');
                      },
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete address',
                onPressed: isUpdating ? null : () => deleteAddress(address),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildDefaultBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Default',
        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
      ),
    );
  }
}
