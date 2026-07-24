import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/store/providers/store_provider.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  Future<void> logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider);
    final currentUser = appUser.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Akun Saya',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: appUser.when(
              data: (user) {
                final displayName = user?.fullName ?? 'Pengguna UMK';
                final emailDisplay = user?.email.isNotEmpty == true
                    ? user!.email
                    : (supabase.auth.currentUser?.email ?? user?.phone ?? '');
                final initial = displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : 'U';

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emailDisplay,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user?.role == 'seller'
                                  ? 'Penjual UMK 🏬'
                                  : user?.role == 'assistant'
                                  ? 'Asisten UMK 🤝'
                                  : 'Pembeli 🛒',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryHover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              error: (error, stackTrace) => Text(error.toString()),
              loading: () => const LinearProgressIndicator(),
            ),
          ),
          const SizedBox(height: 24),

          // Section 1: Profil Saya
          buildSectionTitle('Profil & Belanja'),
          const SizedBox(height: 10),
          buildActionCard(
            children: [
              buildActionTile(
                icon: Icons.person_outline_rounded,
                iconColor: AppColors.primary,
                title: 'Ubah Profil Saya',
                subtitle: 'Nama lengkap, email, dan nomor HP',
                onTap: () => context.push('/account/edit'),
              ),
              const Divider(height: 1, indent: 48),
              buildActionTile(
                icon: Icons.location_on_outlined,
                iconColor: AppColors.primary,
                title: 'Alamat Pengiriman',
                subtitle: 'Atur alamat utama untuk checkout',
                onTap: () => context.push('/addresses'),
              ),
              const Divider(height: 1, indent: 48),
              buildActionTile(
                icon: Icons.receipt_long_outlined,
                iconColor: AppColors.primary,
                title: 'Riwayat Pesanan',
                subtitle: 'Lihat status dan riwayat pembelian',
                onTap: () => context.go('/orders'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 2: Keamanan Akun
          buildSectionTitle('Keamanan & Sandi'),
          const SizedBox(height: 10),
          buildActionCard(
            children: [
              buildActionTile(
                icon: Icons.lock_outline_rounded,
                iconColor: AppColors.primary,
                title: 'Ubah Kata Sandi',
                subtitle: 'Perbarui kata sandi akun Anda',
                onTap: () => context.push('/account/change-password'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 3: Area Penjual UMK
          buildSectionTitle('Usaha UMK'),
          const SizedBox(height: 10),
          buildActionCard(
            children: [
              buildActionTile(
                icon: Icons.storefront_rounded,
                iconColor: AppColors.primary,
                title: 'Toko UMK Saya',
                subtitle: 'Kelola produk, stok, dan pesanan toko',
                onTap: () => openSellerArea(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 3.5: Area Asisten UMK
          buildSectionTitle('Pendampingan UMK'),
          const SizedBox(height: 10),
          buildActionCard(
            children: [
              buildActionTile(
                icon: Icons.handshake_outlined,
                iconColor: Colors.purple.shade700,
                title: 'Dashboard Asisten UMK',
                subtitle: currentUser?.role == 'assistant'
                    ? 'Pendampingan toko UMK, log aksi, & CRUD konten'
                    : 'Daftar atau masuk sebagai Asisten Pendamping UMK',
                onTap: () => openAssistantArea(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 4: Logout
          buildActionCard(
            children: [
              buildActionTile(
                icon: Icons.logout_rounded,
                iconColor: AppColors.error,
                title: 'Keluar Akun',
                subtitle: 'Sign out dari sesi ini',
                textColor: AppColors.error,
                onTap: () => logout(context),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget buildActionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor ?? AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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

  Future<void> openAssistantArea(BuildContext context, WidgetRef ref) async {
    final user = await ref.read(appUserProvider.future);

    if (!context.mounted) return;

    if (user != null && user.isAssistant) {
      context.push('/assistant/dashboard');
      return;
    }

    if (user != null && user.isSeller) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Akun Penjual UMK tidak dapat diubah menjadi Asisten UMK.',
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Daftar Sebagai Asisten UMK'),
        content: const Text(
          'Sebagai Asisten UMK, Anda akan dapat mendampingi toko UMK dalam mengelola produk, pesanan, dan membuat konten promosi.\n\nApakah Anda ingin mengaktifkan akun Asisten UMK?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Aktifkan Akun Asisten'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final service = ref.read(assistantServiceProvider);
        await service.becomeAssistant();
        ref.invalidate(appUserProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Selamat! Akun Anda telah diubah menjadi Asisten UMK.',
              ),
            ),
          );
          context.push('/assistant/dashboard');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal mengubah peran: $e')));
        }
      }
    }
  }
}
