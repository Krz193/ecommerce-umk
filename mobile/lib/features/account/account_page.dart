import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: appUser.when(
              data: (user) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Account',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(user == null ? 'Buyer account' : 'Role: ${user.role}'),
                  ],
                );
              },
              error: (error, stackTrace) {
                return Text(error.toString());
              },
              loading: () {
                return const LinearProgressIndicator();
              },
            ),
          ),
          const SizedBox(height: 16),
          buildActionTile(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Update name, username, and phone',
            onTap: () {
              context.push('/account/edit');
            },
          ),
          const SizedBox(height: 12),
          buildActionTile(
            icon: Icons.location_on_outlined,
            title: 'Addresses',
            subtitle: 'Manage shipping addresses',
            onTap: () {
              context.push('/addresses');
            },
          ),
          const SizedBox(height: 12),
          buildActionTile(
            icon: Icons.receipt_long_outlined,
            title: 'Orders',
            subtitle: 'View order history',
            onTap: () {
              context.go('/orders');
            },
          ),
          const SizedBox(height: 12),
          buildActionTile(
            icon: Icons.storefront_outlined,
            title: 'My Store',
            subtitle: 'Seller dashboard and products',
            onTap: () {
              openSellerArea(context, ref);
            },
          ),
          const SizedBox(height: 12),
          buildActionTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out from this account',
            onTap: () async {
              await logout();
            },
          ),
        ],
      ),
    );
  }

  Widget buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
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
