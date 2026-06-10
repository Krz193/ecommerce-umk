import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/cart/widgets/cart_action_button.dart';
import 'package:mobile/features/product/providers/product_provider.dart';
import 'package:mobile/features/store/providers/store_provider.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Store',

            onPressed: () {
              openSellerArea(context, ref);
            },

            icon: const Icon(Icons.storefront_outlined),
          ),

          const CartActionButton(),

          IconButton(
            onPressed: () {
              context.push('/orders');
            },

            icon: const Icon(Icons.receipt_long),
          ),

          IconButton(
            onPressed: () async {
              await logout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ref
          .watch(productsProvider)
          .when(
            data: (products) {
              return ListView(
                padding: const EdgeInsets.all(16),

                children: [
                  buildSellerEntry(context, ref),

                  const SizedBox(height: 16),

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

  Widget buildSellerEntry(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider);
    final myStore = ref.watch(myStoreProvider);

    final storeLabel = myStore.maybeWhen(
      data: (store) => store == null ? 'Start Selling' : 'Store: ${store.name}',
      orElse: () => 'Store',
    );

    final roleLabel = appUser.maybeWhen(
      data: (user) => user == null ? 'Buyer account' : 'Role: ${user.role}',
      orElse: () => 'Checking role',
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),

      onTap: () {
        openSellerArea(context, ref);
      },

      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),

        child: Row(
          children: [
            const Icon(Icons.storefront_outlined),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    storeLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 4),

                  Text(roleLabel),
                ],
              ),
            ),

            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  void openSellerArea(BuildContext context, WidgetRef ref) {
    final store = ref.read(myStoreProvider).asData?.value;

    if (store == null) {
      context.push('/seller/onboarding');
      return;
    }

    context.push('/seller/store');
  }
}
