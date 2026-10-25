import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/error_formatter.dart';
import 'package:mobile/features/assistant/models/assistant_profile_model.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';
import 'package:mobile/features/order/providers/seller_order_provider.dart';
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
                ref.invalidate(sellerOrdersProvider(activeStore.storeId));
                ref.invalidate(
                  storeDonationsSummaryProvider(activeStore.storeId),
                );
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  const Text(
                    'Toko UMK Aktif Dampingan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (stores.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
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

                  if (activeStore != null) ...[
                    const SizedBox(height: 20),
                    _buildStoreSalesAndDonationsPanel(
                      context,
                      ref,
                      activeStore,
                    ),
                  ],

                  const SizedBox(height: 24),

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
                        subtitle: 'Medsos, Video & Gambar',
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
                        title: 'CRUD Engagement',
                        subtitle: 'Reach, Likes & Aktivitas',
                        icon: Icons.insights_outlined,
                        color: Colors.purple.shade700,
                        onTap: () => context.push(
                          '/assistant/logs${activeStore != null ? '?storeId=${activeStore.storeId}' : ''}',
                        ),
                      ),
                      _buildMenuCard(
                        context,
                        title: 'Rekomendasi Produk',
                        subtitle: 'Model Rumus & Unggulan',
                        icon: Icons.auto_awesome_outlined,
                        color: Colors.amber.shade800,
                        onTap: activeStore == null
                            ? null
                            : () => context.push(
                                '/seller/recommendations?storeId=${activeStore.storeId}',
                              ),
                      ),
                      _buildMenuCard(
                        context,
                        title: 'Keranjang Pembeli',
                        subtitle: 'Pantau Keranjang Aktif',
                        icon: Icons.shopping_cart_checkout,
                        color: Colors.blue.shade800,
                        onTap: activeStore == null
                            ? null
                            : () => context.push(
                                '/seller/buyer-carts?storeId=${activeStore.storeId}',
                              ),
                      ),
                      _buildMenuCard(
                        context,
                        title: 'Laporan UKM Binaan',
                        subtitle: 'Penjualan & Ekspor CSV',
                        icon: Icons.analytics_outlined,
                        color: Colors.green.shade700,
                        onTap: activeStore == null
                            ? null
                            : () => context.push('/seller/reports'),
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
                      _buildMenuCard(
                        context,
                        title: 'Profil Asisten',
                        subtitle: 'Lihat Akun Asisten',
                        icon: Icons.badge_outlined,
                        color: Colors.blueGrey.shade700,
                        onTap: () => context.push('/assistant/profile'),
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

  Widget _buildStoreSalesAndDonationsPanel(
    BuildContext context,
    WidgetRef ref,
    AssignedStoreInfo activeStore,
  ) {
    final ordersAsync = ref.watch(sellerOrdersProvider(activeStore.storeId));
    final donationsAsync = ref.watch(
      storeDonationsSummaryProvider(activeStore.storeId),
    );

    final orders = ordersAsync.asData?.value ?? [];
    final paidOrders = orders
        .where(
          (o) =>
              o.paymentStatus == 'paid' &&
              o.status != 'cancelled' &&
              o.status != 'failed',
        )
        .toList();
    final totalSalesRevenue = paidOrders.fold<int>(
      0,
      (sum, o) => sum + o.totalAmount,
    );

    final donationMap = donationsAsync.asData?.value ?? {};
    final totalDonationsCollected =
        (donationMap['total_collected'] as num?)?.toInt() ?? 0;
    final totalDonationsDistributed =
        (donationMap['total_distributed'] as num?)?.toInt() ?? 0;
    final donorCount = (donationMap['donor_count'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
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
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.volunteer_activism_outlined,
                      color: Colors.teal.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Penjualan & Donasi UKM Binaan (${activeStore.storeName})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/seller/reports'),
                child: const Text('Detail >'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  label: 'Penjualan Lunas',
                  value: CurrencyFormatter.format(totalSalesRevenue),
                  sub: '${paidOrders.length} transaksi',
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox(
                  label: 'Donasi Terkumpul',
                  value: CurrencyFormatter.format(totalDonationsCollected),
                  sub: '$donorCount donatur',
                  color: Colors.pink.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  label: 'Donasi Disalurkan',
                  value: CurrencyFormatter.format(totalDonationsDistributed),
                  sub: 'Diterima UKM Binaan',
                  color: Colors.indigo.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox(
                  label: 'Total Pesanan',
                  value: '${orders.length} Pesanan',
                  sub: 'Semua status order',
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
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
