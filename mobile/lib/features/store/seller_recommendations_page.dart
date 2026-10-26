import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerRecommendationsPage extends ConsumerStatefulWidget {
  final String? storeId;

  const SellerRecommendationsPage({super.key, this.storeId});

  @override
  ConsumerState<SellerRecommendationsPage> createState() =>
      _SellerRecommendationsPageState();
}

class _SellerRecommendationsPageState
    extends ConsumerState<SellerRecommendationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addToRecommendations(
    Map<String, dynamic> item,
    String targetStoreId,
  ) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(storeServiceProvider);
      await service.saveProductRecommendation(
        productId: item['product_id'],
        priority: 1,
        badgeText: 'Pilihan Seller',
        isActive: true,
      );

      ref.invalidate(storeRecommendationMetricsProvider(targetStoreId));
      ref.invalidate(publicStoreRecommendedProductsProvider(targetStoreId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item['product_name']} ditambahkan ke rekomendasi!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan rekomendasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _removeFromRecommendations(
    Map<String, dynamic> item,
    String targetStoreId,
  ) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(storeServiceProvider);
      await service.removeProductRecommendation(item['product_id']);

      ref.invalidate(storeRecommendationMetricsProvider(targetStoreId));
      ref.invalidate(publicStoreRecommendedProductsProvider(targetStoreId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item['product_name']} dihapus dari rekomendasi'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus rekomendasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _applyAutoTopRecommendations(String targetStoreId) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(storeServiceProvider);
      final count = await service.applyAutoStoreRecommendations(
        storeId: targetStoreId,
        topN: 3,
      );

      ref.invalidate(storeRecommendationMetricsProvider(targetStoreId));
      ref.invalidate(publicStoreRecommendedProductsProvider(targetStoreId));

      if (mounted) {
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$count produk terbaik otomatis ditetapkan sebagai rekomendasi toko.',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menerapkan rekomendasi otomatis: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showEditBadgeDialog(
    Map<String, dynamic> item,
    String targetStoreId,
  ) {
    final textController = TextEditingController(
      text: item['badge_text']?.toString() ?? 'Pilihan Seller',
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Ubah Lencana Rekomendasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['product_name'] ?? 'Produk',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Label Lencana (Badge)',
                hintText: 'Contoh: Terlaris, Unggulan, Spesial',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() => _isProcessing = true);
              try {
                final service = ref.read(storeServiceProvider);
                await service.saveProductRecommendation(
                  productId: item['product_id'],
                  priority: item['priority'] ?? 1,
                  badgeText: textController.text.trim().isEmpty
                      ? null
                      : textController.text.trim(),
                  isActive: true,
                );
                ref.invalidate(storeRecommendationMetricsProvider(targetStoreId));
                ref.invalidate(publicStoreRecommendedProductsProvider(targetStoreId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lencana rekomendasi berhasil diperbarui')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal memperbarui lencana: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final managedStoreAsync = ref.watch(managedStoreProvider);

    return managedStoreAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Rekomendasi Produk')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Rekomendasi Produk')),
        body: Center(child: Text('Gagal memuat toko: $err')),
      ),
      data: (managedStore) {
        final targetStoreId = (widget.storeId != null && widget.storeId!.isNotEmpty)
            ? widget.storeId
            : managedStore?.id;

        if (targetStoreId == null || targetStoreId.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Rekomendasi Produk')),
            body: const Center(
              child: Text('Toko UMK belum dipilih atau belum terdaftar.'),
            ),
          );
        }

        final metricsAsync = ref.watch(
          storeRecommendationMetricsProvider(targetStoreId),
        );

        return metricsAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Rekomendasi Produk')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Scaffold(
            appBar: AppBar(title: const Text('Rekomendasi Produk')),
            body: Center(child: Text('Gagal memuat katalog produk: $err')),
          ),
          data: (items) {
            final recommendedItems = items
                .where((e) => e['is_recommended'] == true)
                .toList();
            final availableItems = items
                .where((e) => e['is_recommended'] != true)
                .toList();

            return Scaffold(
              appBar: AppBar(
                title: const Text('Rekomendasi Produk Toko'),
                bottom: TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, size: 18),
                          const SizedBox(width: 6),
                          Text('Rekomendasi (${recommendedItems.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 18),
                          const SizedBox(width: 6),
                          Text('Katalog Toko (${availableItems.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              body: Stack(
                children: [
                  Column(
                    children: [
                      if (items.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(15),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Pilih otomatis 3 produk terbaik dari performa penjualan & ulasan toko.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _isProcessing
                                    ? null
                                    : () => _applyAutoTopRecommendations(
                                          targetStoreId,
                                        ),
                                child: const Text('Set Top 3'),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 1: Rekomendasi Aktif
                            _buildRecommendedList(
                              recommendedItems,
                              targetStoreId,
                            ),
                            // Tab 2: Katalog Toko untuk Ditambahkan
                            _buildAvailableList(
                              availableItems,
                              targetStoreId,
                              items.isNotEmpty,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isProcessing)
                    Container(
                      color: Colors.black26,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecommendedList(
    List<Map<String, dynamic>> items,
    String targetStoreId,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Belum Ada Produk yang Direkomendasikan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih produk dari tab "Katalog Toko" untuk ditampilkan sebagai produk rekomendasi unggulan di halaman toko Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.add),
                label: const Text('Tambah dari Katalog'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final badge = item['badge_text']?.toString() ?? 'Pilihan Toko';
        final price = (item['price'] as num?)?.toInt() ?? 0;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 64,
                    height: 64,
                    color: Colors.grey.shade100,
                    child: (item['thumbnail_url'] != null &&
                            item['thumbnail_url'].toString().isNotEmpty)
                        ? Image.network(
                            item['thumbnail_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                          )
                        : const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['product_name'] ?? 'Produk',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(price),
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Colors.blue),
                  tooltip: 'Ubah Label Lencana',
                  onPressed: () => _showEditBadgeDialog(item, targetStoreId),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Hapus dari Rekomendasi',
                  onPressed: () => _removeFromRecommendations(item, targetStoreId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailableList(
    List<Map<String, dynamic>> items,
    String targetStoreId,
    bool hasAnyProductInStore,
  ) {
    if (!hasAnyProductInStore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Belum Ada Produk di Toko',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Toko Anda belum memiliki produk. Tambahkan produk terlebih dahulu di menu Kelola Produk.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 56, color: Colors.green.shade400),
              const SizedBox(height: 16),
              const Text(
                'Semua Produk Sudah Direkomendasikan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Seluruh katalog produk toko Anda telah masuk ke dalam daftar rekomendasi unggulan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final price = (item['price'] as num?)?.toInt() ?? 0;
        final stock = (item['stock'] as num?)?.toInt() ?? 0;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                color: Colors.grey.shade100,
                child: (item['thumbnail_url'] != null &&
                        item['thumbnail_url'].toString().isNotEmpty)
                    ? Image.network(
                        item['thumbnail_url'],
                        fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                      )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
            title: Text(
              item['product_name'] ?? 'Produk',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${CurrencyFormatter.format(price)} • Stok: $stock',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _addToRecommendations(item, targetStoreId),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Rekomendasikan'),
            ),
          ),
        );
      },
    );
  }
}
