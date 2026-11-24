import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/error_formatter.dart';
import 'package:mobile/features/assistant/models/store_content_model.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';
import 'package:mobile/features/store/providers/store_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher/url_launcher.dart';

class StoreContentListPage extends ConsumerStatefulWidget {
  final String storeId;
  final String? storeName;
  final bool isReadOnly;

  const StoreContentListPage({
    super.key,
    required this.storeId,
    this.storeName,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<StoreContentListPage> createState() =>
      _StoreContentListPageState();
}

class _StoreContentListPageState extends ConsumerState<StoreContentListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedPlatform = 'all';
  String _searchQuery = '';

  static const List<Map<String, String>> _platformFilters = [
    {'id': 'all', 'label': 'Semua'},
    {'id': 'instagram', 'label': 'Instagram'},
    {'id': 'tiktok', 'label': 'TikTok'},
    {'id': 'youtube', 'label': 'YouTube'},
    {'id': 'facebook', 'label': 'Facebook'},
    {'id': 'whatsapp', 'label': 'WhatsApp'},
    {'id': 'marketplace', 'label': 'Marketplace'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StoreContentModel> _filterContents(List<StoreContentModel> contents) {
    final query = _searchQuery.trim().toLowerCase();
    return contents.where((item) {
      if (_selectedPlatform != 'all' &&
          item.socialPlatform != _selectedPlatform) {
        return false;
      }
      if (query.isEmpty) return true;
      final corpus = <String>[
        item.title,
        if (item.body != null) item.body!,
        if (item.creatorName != null) item.creatorName!,
        if (item.productName != null) item.productName!,
        item.socialPlatformLabel,
        item.contentTypeLabel,
        item.mediaFormatLabel,
        if (item.externalUrl != null) item.externalUrl!,
      ].join(' ').toLowerCase();
      return corpus.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final myStore = ref.watch(myStoreProvider).asData?.value;
    final selectedStore = ref.watch(selectedStoreProvider);
    final assignedStores = ref.watch(assignedStoresProvider).asData?.value;

    final effectiveStoreId = widget.storeId.trim().isNotEmpty
        ? widget.storeId.trim()
        : (widget.isReadOnly
              ? (myStore?.id ?? '')
              : (selectedStore?.storeId ??
                    myStore?.id ??
                    assignedStores?.firstOrNull?.storeId ??
                    ''));

    final effectiveStoreName =
        (widget.storeName != null && widget.storeName!.trim().isNotEmpty)
        ? widget.storeName!.trim()
        : (widget.isReadOnly
              ? myStore?.name
              : (selectedStore?.storeName ??
                    myStore?.name ??
                    assignedStores?.firstOrNull?.storeName));

    final appBarTitle = widget.isReadOnly
        ? 'Monitoring Konten & Engagement'
        : ((effectiveStoreName != null && effectiveStoreName.isNotEmpty)
              ? 'Konten & Engagement $effectiveStoreName'
              : 'Konten & Engagement');

    if (effectiveStoreId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(appBarTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Toko Belum Ditemukan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tidak ada data toko yang dipilih atau ditugaskan untuk melihat konten.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final contentsAsync = ref.watch(storeContentsProvider(effectiveStoreId));

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(storeContentsProvider(effectiveStoreId)),
          ),
        ],
      ),
      floatingActionButton: widget.isReadOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openCreateForm(effectiveStoreId),
              icon: const Icon(Icons.add),
              label: const Text('Catat Konten'),
            ),
      body: contentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat konten: ${formatUserFriendlyError(err)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(storeContentsProvider(effectiveStoreId)),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (contents) {
          final filtered = _filterContents(contents);

          return Column(
            children: [
              if (widget.isReadOnly)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        color: Colors.teal.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          effectiveStoreName != null &&
                                  effectiveStoreName.isNotEmpty
                              ? 'Monitoring konten & engagement toko $effectiveStoreName yang diunggah Asisten UMK (Read-Only).'
                              : 'Monitoring konten & engagement yang diunggah Asisten UMK (Read-Only).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                    ),
                    hintText:
                        'Cari judul, platform, produk, atau nama asisten...',
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

              // Platform Filter Chips
              SizedBox(
                height: 46,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _platformFilters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final pf = _platformFilters[index];
                    final isSelected = _selectedPlatform == pf['id'];
                    return ChoiceChip(
                      label: Text(pf['label']!),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withAlpha(35),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedPlatform = pf['id']!;
                        });
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(storeContentsProvider(effectiveStoreId));
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      widget.isReadOnly ? 24 : 88,
                    ),
                    children: [
                      _buildSummaryCard(filtered),
                      const SizedBox(height: 16),
                      if (contents.isEmpty)
                        _buildEmptyState(effectiveStoreId)
                      else if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.filter_alt_off_outlined,
                                size: 52,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Tidak ada konten yang cocok dengan filter',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _selectedPlatform = 'all';
                                    _searchQuery = '';
                                  });
                                },
                                child: const Text('Reset Filter'),
                              ),
                            ],
                          ),
                        )
                      else
                        ...filtered.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildContentCard(
                              context,
                              item,
                              effectiveStoreId,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCreateForm(String effectiveStoreId) async {
    final result = await context.push<bool>(
      '/assistant/contents/create?storeId=$effectiveStoreId',
    );
    if (result == true) {
      ref.invalidate(storeContentsProvider(effectiveStoreId));
      ref.invalidate(assistanceLogsProvider(effectiveStoreId));
    }
  }

  Future<void> _openEditForm(
    StoreContentModel item,
    String effectiveStoreId,
  ) async {
    final result = await context.push<bool>(
      '/assistant/contents/edit/${item.id}?storeId=$effectiveStoreId',
      extra: item,
    );
    if (result == true) {
      ref.invalidate(storeContentsProvider(effectiveStoreId));
      ref.invalidate(assistanceLogsProvider(effectiveStoreId));
    }
  }

  Widget _buildSummaryCard(List<StoreContentModel> items) {
    final totalContents = items.length;
    final totalReach = items.fold<int>(0, (s, c) => s + c.reachCount);
    final totalLikes = items.fold<int>(0, (s, c) => s + c.likesCount);
    final totalComments = items.fold<int>(0, (s, c) => s + c.commentsCount);
    final totalShares = items.fold<int>(0, (s, c) => s + c.sharesCount);
    final totalInquiries = items.fold<int>(0, (s, c) => s + c.inquiriesCount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.purple.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ringkasan Konten & Performa Engagement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildSummaryPill('Total Konten', totalContents.toString()),
              _buildSummaryPill('Views / Reach', totalReach.toString()),
              _buildSummaryPill('Likes', totalLikes.toString()),
              _buildSummaryPill('Komentar', totalComments.toString()),
              _buildSummaryPill('Shares', totalShares.toString()),
              _buildSummaryPill('Leads / Chat', totalInquiries.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String effectiveStoreId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            widget.isReadOnly
                ? 'Belum Ada Konten dari Asisten UMK'
                : 'Belum Ada Konten & Engagement',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.isReadOnly
                  ? 'Asisten pendamping belum mencatat link bukti konten platform eksternal atau angka engagement untuk toko ini.'
                  : 'Catat platform eksternal tempat konten UMK diupload, link bukti tayang, dan angka engagement (Reach, Likes, Komentar, Share, Leads).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          if (!widget.isReadOnly) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openCreateForm(effectiveStoreId),
              icon: const Icon(Icons.add),
              label: const Text('Catat Konten Pertama'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentCard(
    BuildContext context,
    StoreContentModel item,
    String currentStoreId,
  ) {
    final hasExternalUrl =
        item.externalUrl != null && item.externalUrl!.trim().isNotEmpty;
    final hasProduct =
        item.productName != null && item.productName!.trim().isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.isReadOnly
            ? null
            : () => _openEditForm(item, currentStoreId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges & optional Edit/Delete actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Text(
                            item.socialPlatformLabel,
                            style: TextStyle(
                              color: Colors.purple.shade900,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.contentTypeLabel,
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.mediaFormatLabel,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isReadOnly)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          onPressed: () => _openEditForm(item, currentStoreId),
                        ),
                        IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              _confirmDelete(context, item, currentStoreId),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),

              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Diupload oleh Asisten: ${item.creatorName ?? 'Asisten UMK'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormatter.format(item.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),

              if (item.body != null && item.body!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.body!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
              ],

              if (hasProduct) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 16,
                        color: Colors.amber.shade900,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.productName!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.productPrice != null)
                        Text(
                          CurrencyFormatter.format(item.productPrice!),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // Engagement Metrics Box
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Performa Engagement',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '${item.totalInteractions} Total Interaksi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _buildSmallStat(
                          Icons.visibility_outlined,
                          '${item.reachCount} Reach',
                        ),
                        _buildSmallStat(
                          Icons.favorite_border,
                          '${item.likesCount} Likes',
                        ),
                        _buildSmallStat(
                          Icons.chat_bubble_outline,
                          '${item.commentsCount} Komentar',
                        ),
                        _buildSmallStat(
                          Icons.share_outlined,
                          '${item.sharesCount} Share',
                        ),
                        _buildSmallStat(
                          Icons.mark_chat_unread_outlined,
                          '${item.inquiriesCount} Leads',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (hasExternalUrl) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () =>
                          _openExternalUrl(context, item.externalUrl!),
                      icon: const Icon(Icons.open_in_new, size: 15),
                      label: Text(
                        'Buka Bukti di ${item.socialPlatformLabel}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: item.externalUrl!.trim()),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link bukti konten berhasil disalin!'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_outlined, size: 15),
                      label: const Text(
                        'Salin Link',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.indigo.shade700),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Future<void> _openExternalUrl(BuildContext context, String rawUrl) async {
    final trimmed = rawUrl.trim();
    final normalized =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Format link bukti tidak valid.')),
        );
      }
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka tautan eksternal.')),
      );
    }
  }

  void _confirmDelete(
    BuildContext context,
    StoreContentModel item,
    String currentStoreId,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Konten UMK'),
        content: Text(
          'Apakah Anda yakin ingin menghapus konten "${item.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final service = ref.read(assistantServiceProvider);
                await service.deleteStoreContent(
                  contentId: item.id,
                  storeId: currentStoreId,
                  title: item.title,
                );
                ref.invalidate(storeContentsProvider(currentStoreId));
                ref.invalidate(assistanceLogsProvider(currentStoreId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Konten berhasil dihapus')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Gagal menghapus konten: ${formatUserFriendlyError(e)}',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
