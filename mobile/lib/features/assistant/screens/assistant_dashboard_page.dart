import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/error_formatter.dart';
import 'package:mobile/features/assistant/models/assistant_profile_model.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class AssistantDashboardPage extends ConsumerWidget {
  const AssistantDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(assistantProfileProvider);
    final selectedStore = ref.watch(selectedStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Asisten UMK'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profil Asisten',
            onPressed: () => context.push('/assistant/profile'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  formatUserFriendlyError(err),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(assistantProfileProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Data profil tidak ditemukan'));
          }

          final stores = profile.assignedStores;
          final activeStore =
              selectedStore ?? (stores.isNotEmpty ? stores.first : null);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(assistantProfileProvider);
              if (activeStore != null) {
                ref.invalidate(assistanceLogsProvider(activeStore.storeId));
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Assistant Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            profile.fullName.isNotEmpty
                                ? profile.fullName[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.fullName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Asisten UMK Terverifikasi 🤝',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Store Selection Header
                  const Text(
                    'Toko UMK Aktif Dampingan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (stores.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, color: Colors.amber),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Belum ada Toko UMK yang ditugaskan ke akun Anda. Hubungi Admin atau Pemilik UMK.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AssignedStoreInfo>(
                            isExpanded: true,
                            value: activeStore,
                            items: stores.map((store) {
                              return DropdownMenuItem<AssignedStoreInfo>(
                                value: store,
                                child: Row(
                                  children: [
                                    Icon(Icons.store, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        store.storeName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (store.storeCity != null)
                                      Text(
                                        store.storeCity!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newStore) {
                              if (newStore != null) {
                                ref
                                    .read(selectedStoreProvider.notifier)
                                    .selectStore(newStore);
                              }
                            },
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Menu Grid
                  const Text(
                    'Fitur Asistensi & Pendampingan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _buildMenuCard(
                        context,
                        title: 'Konten Promosi',
                        subtitle: 'Kelola Konten & Promosi',
                        icon: Icons.article_outlined,
                        color: Colors.orange.shade700,
                        onTap: activeStore == null
                            ? null
                            : () => context.push(
                                '/assistant/contents?storeId=${activeStore.storeId}&storeName=${Uri.encodeComponent(activeStore.storeName)}',
                              ),
                      ),
                      _buildMenuCard(
                        context,
                        title: 'Riwayat Pendampingan',
                        subtitle: 'Catatan Aktivitas Pendampingan',
                        icon: Icons.history_edu,
                        color: Colors.purple.shade700,
                        onTap: () => context.push(
                          '/assistant/logs${activeStore != null ? '?storeId=${activeStore.storeId}' : ''}',
                        ),
                      ),
                      _buildMenuCard(
                        context,
                        title: 'Profil Asisten',
                        subtitle: 'Lihat Akun Asisten',
                        icon: Icons.badge_outlined,
                        color: Colors.blue.shade700,
                        onTap: () => context.push('/assistant/profile'),
                      ),
                      _buildMenuCard(
                        context,
                        title: 'Profil Toko UMK',
                        subtitle: 'Kelola Informasi Toko',
                        icon: Icons.storefront_outlined,
                        color: Colors.deepOrange.shade700,
                        onTap: () async {
                          final targetStoreId = activeStore?.storeId;
                          if (targetStoreId == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Belum ada Toko UMK yang didampingi.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }

                          final storeService = ref.read(storeServiceProvider);
                          final store = await storeService.getStoreById(
                            targetStoreId,
                          );
                          if (store != null && context.mounted) {
                            context.push('/seller/edit-store', extra: store);
                          }
                        },
                      ),
                      _buildMenuCard(
                        context,
                        title: 'Produk UMK',
                        subtitle: 'Kelola Produk & Stok',
                        icon: Icons.inventory_2_outlined,
                        color: Colors.teal.shade700,
                        onTap: () => context.push('/seller/products'),
                      ),
                      _buildMenuCard(
                        context,
                        title: 'Pesanan UMK',
                        subtitle: 'Kelola Pengiriman',
                        icon: Icons.local_shipping_outlined,
                        color: Colors.indigo.shade700,
                        onTap: () => context.push('/seller/orders'),
                      ),
                      _buildMenuCard(
                        context,
                        title: 'Ulasan Produk',
                        subtitle: 'Respon Ulasan Pembeli',
                        icon: Icons.rate_review_outlined,
                        color: Colors.teal.shade700,
                        onTap: () => context.push('/seller/reviews'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final bool isDisabled = onTap == null;
    return Material(
      color: isDisabled ? Colors.grey.shade200 : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: isDisabled ? 0 : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDisabled ? Colors.grey.shade300 : color.withAlpha(50),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? Colors.grey.shade400
                      : color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDisabled ? Colors.grey.shade600 : color,
                  size: 24,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDisabled ? Colors.grey.shade600 : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
