import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/error_formatter.dart';
import 'package:mobile/features/assistant/models/store_content_model.dart';
import 'package:mobile/features/donation/services/buyer_donation_service.dart';
import 'package:mobile/features/explore/explore_providers.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher/url_launcher.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  String _placementScope = 'all'; // 'all', 'product', 'non_product'
  String _searchQuery = '';

  final List<Map<String, String>> _categories = const [
    {'id': 'all', 'label': 'Semua ✨'},
    {'id': 'promo', 'label': 'Promo Diskon 🏷️'},
    {'id': 'storytelling', 'label': 'Kisah UMK 📖'},
    {'id': 'banner', 'label': 'Spanduk & Banner 📢'},
    {'id': 'social', 'label': 'Media Sosial 📱'},
    {'id': 'educational', 'label': 'Edukasi 💡'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StoreContentModel> _filterContents(List<StoreContentModel> contents) {
    final query = _searchQuery.trim().toLowerCase();
    return contents.where((item) {
      final hasProduct = item.productId != null && item.productId!.isNotEmpty;
      if (_placementScope == 'product' && !hasProduct) return false;
      if (_placementScope == 'non_product' && hasProduct) return false;

      if (query.isEmpty) return true;
      final corpus = <String>[
        item.title,
        if (item.body != null) item.body!,
        if (item.storeName != null) item.storeName!,
        if (item.productName != null) item.productName!,
        item.contentTypeLabel,
        item.mediaFormatLabel,
        item.socialPlatformLabel,
      ].join(' ').toLowerCase();
      return corpus.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final contentsAsync = ref.watch(
      publicStoreContentsProvider(_selectedCategory),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Jelajah & Promosi UMK',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Riwayat & CRUD Donasi Saya',
            onPressed: () => context.push('/donations'),
            icon: const Icon(Icons.volunteer_activism_outlined),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar (#7)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                hintText:
                    'Cari promosi produk, kisah UMK, toko, atau platform...',
                isDense: true,
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Pakem Placement Scope Selector (#8: Produk vs Non-Produk)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPlacementScopeChip(
                    id: 'all',
                    label: 'Semua Penempatan',
                    icon: Icons.layers_outlined,
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _buildPlacementScopeChip(
                    id: 'product',
                    label: 'Zona Promosi Produk 🏷️',
                    icon: Icons.local_offer_outlined,
                    activeColor: Colors.amber.shade900,
                  ),
                  const SizedBox(width: 8),
                  _buildPlacementScopeChip(
                    id: 'non_product',
                    label: 'Zona Non-Produk & Kisah UMK 📖',
                    icon: Icons.auto_stories_outlined,
                    activeColor: Colors.teal.shade700,
                  ),
                ],
              ),
            ),
          ),

          // Category Filter Chips Bar
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat['id'];
                return FilterChip(
                  label: Text(cat['label']!),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withAlpha(40),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = cat['id']!;
                    });
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Main Feed List
          Expanded(
            child: contentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        formatUserFriendlyError(err),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.refresh(
                          publicStoreContentsProvider(_selectedCategory),
                        ),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (contents) {
                final filtered = _filterContents(contents);

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.explore_off_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Belum ada konten promosi yang sesuai',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Coba ubah filter zona penempatan, kategori, atau kata kunci.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(
                      publicStoreContentsProvider(_selectedCategory),
                    );
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildContentCard(context, item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacementScopeChip({
    required String id,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _placementScope == id;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected ? activeColor : AppColors.textSecondary,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: activeColor.withAlpha(28),
      labelStyle: TextStyle(
        color: isSelected ? activeColor : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() {
          _placementScope = id;
        });
      },
    );
  }

  Widget _buildContentCard(BuildContext context, StoreContentModel item) {
    final hasProduct = item.productId != null && item.productId!.isNotEmpty;
    final hasExternalUrl =
        item.externalUrl != null && item.externalUrl!.trim().isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasProduct ? Colors.amber.shade300 : Colors.teal.shade200,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pakem Placement Banner Header (#8)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: hasProduct ? Colors.amber.shade50 : Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    hasProduct
                        ? Icons.local_offer_rounded
                        : Icons.auto_stories_rounded,
                    size: 14,
                    color: hasProduct
                        ? Colors.amber.shade900
                        : Colors.teal.shade800,
                  ),
                  Text(
                    hasProduct
                        ? 'ZONA PROMOSI PRODUK'
                        : 'ZONA INFORMASI & KISAH NON-PRODUK UMK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasProduct
                          ? Colors.amber.shade900
                          : Colors.teal.shade800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.mediaFormatLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (item.socialPlatform != 'none')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.socialPlatformLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Store Header Row
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withAlpha(30),
                  child: const Icon(
                    Icons.storefront,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.storeName ?? 'Toko UMK',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        DateFormatter.format(item.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.contentTypeLabel,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Content Title
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),

            if (item.body != null && item.body!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.body!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Media Gallery Preview (Only if photo uploaded)
            if (item.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    item.mediaUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            ],

            // Linked Product Highlight Box (If Available)
            if (hasProduct) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          item.productThumbnailUrl != null &&
                              item.productThumbnailUrl!.isNotEmpty
                          ? Image.network(
                              item.productThumbnailUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 44,
                                    height: 44,
                                    color: AppColors.primary.withAlpha(30),
                                    child: const Icon(
                                      Icons.shopping_bag_outlined,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              color: AppColors.primary.withAlpha(30),
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName ?? 'Produk Dipromosikan',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.productPrice != null)
                            Text(
                              CurrencyFormatter.format(item.productPrice!),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.push('/products/${item.productId}');
                      },
                      icon: const Icon(
                        Icons.shopping_cart_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: const Text('Beli', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // External Media Sosial Actions (#17)
            if (hasExternalUrl) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _openExternalUrl(context, item.externalUrl!),
                    icon: const Icon(Icons.open_in_new, size: 15),
                    label: Text(
                      item.socialPlatform != 'none'
                          ? 'Buka di ${item.socialPlatformLabel}'
                          : 'Buka Tautan',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: item.externalUrl!),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link konten disalin ke clipboard.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 15),
                    label: const Text(
                      'Salin Link',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Action Footer Buttons: Kunjungi Toko & Donasi ke UMK (#12)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/store/${item.storeId}');
                    },
                    icon: const Icon(Icons.store, size: 16),
                    label: Text(
                      'Toko ${item.storeName ?? "UMK"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showBuyerDonationDialog(
                        context,
                        ref,
                        storeId: item.storeId,
                        storeName: item.storeName ?? 'Toko UMK',
                        contentId: item.id,
                        contentTitle: item.title,
                      );
                    },
                    icon: const Icon(
                      Icons.volunteer_activism,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Donasi UMK',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternalUrl(BuildContext context, String rawUrl) async {
    final normalized =
        rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
        ? rawUrl
        : 'https://$rawUrl';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka tautan eksternal.')),
      );
    }
  }
}
