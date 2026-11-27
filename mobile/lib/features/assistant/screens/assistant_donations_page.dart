import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/error_formatter.dart';
import 'package:mobile/features/assistant/models/assistant_profile_model.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';
import 'package:mobile/features/donation/services/buyer_donation_service.dart';

class AssistantDonationsPage extends ConsumerStatefulWidget {
  final String? storeId;

  const AssistantDonationsPage({super.key, this.storeId});

  @override
  ConsumerState<AssistantDonationsPage> createState() =>
      _AssistantDonationsPageState();
}

class _AssistantDonationsPageState
    extends ConsumerState<AssistantDonationsPage> {
  String? _selectedStoreIdOverride;
  String _statusFilter = 'all'; // 'all', 'paid', 'distributed', 'pending', 'expired_or_failed'
  String _sourceFilter = 'all'; // 'all', 'content', 'direct'

  AssignedStoreInfo? _resolveActiveStore(
    List<AssignedStoreInfo> stores,
    AssignedStoreInfo? selectedFromProvider,
  ) {
    if (stores.isEmpty) return null;

    final targetId =
        _selectedStoreIdOverride ??
        (widget.storeId != null && widget.storeId!.trim().isNotEmpty
            ? widget.storeId!.trim()
            : selectedFromProvider?.storeId);

    if (targetId != null) {
      for (final store in stores) {
        if (store.storeId == targetId) return store;
      }
    }

    return stores.first;
  }

  List<BuyerDonationRecord> _applyFilters(List<BuyerDonationRecord> items) {
    return items.where((item) {
      if (_statusFilter == 'paid' && item.status != 'paid') return false;
      if (_statusFilter == 'distributed' && item.status != 'distributed') {
        return false;
      }
      if (_statusFilter == 'pending' && item.status != 'pending') return false;
      if (_statusFilter == 'expired_or_failed' &&
          !['expired', 'failed', 'cancelled'].contains(item.status)) {
        return false;
      }

      final hasContent =
          item.contentId != null && item.contentId!.trim().isNotEmpty;
      if (_sourceFilter == 'content' && !hasContent) return false;
      if (_sourceFilter == 'direct' && hasContent) return false;

      return true;
    }).toList();
  }

  Future<void> _copyStoreDonationLink(String storeId) async {
    final link = buildDonationPageLink(storeId: storeId);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link halaman donasi toko disalin: $link')),
    );
  }

  Future<void> _copyContentDonationLink(
    String storeId,
    String contentId,
  ) async {
    final link = buildDonationPageLink(
      storeId: storeId,
      contentId: contentId,
    );
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link donasi konten disalin untuk disisipkan ke caption.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(assignedStoresProvider);
    final selectedFromProvider = ref.watch(selectedStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Donasi UMK'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang Data Donasi',
            onPressed: () {
              ref.invalidate(assignedStoresProvider);
              final stores = storesAsync.asData?.value ?? [];
              final active = _resolveActiveStore(stores, selectedFromProvider);
              if (active != null) {
                ref.invalidate(storeDonationsSummaryProvider(active.storeId));
              }
            },
          ),
        ],
      ),
      body: storesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(formatUserFriendlyError(err)),
          ),
        ),
        data: (stores) {
          final activeStore = _resolveActiveStore(stores, selectedFromProvider);
          if (activeStore == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada Toko UMK yang ditugaskan ke akun Asisten Anda.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final summaryAsync = ref.watch(
            storeDonationsSummaryProvider(activeStore.storeId),
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(storeDonationsSummaryProvider(activeStore.storeId));
            },
            child: summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Gagal memuat data donasi: ${formatUserFriendlyError(err)}'),
                ],
              ),
              data: (summary) {
                final donations =
                    (summary['donations'] as List<dynamic>?)
                        ?.whereType<BuyerDonationRecord>()
                        .toList() ??
                    <BuyerDonationRecord>[];
                final filtered = _applyFilters(donations);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildStoreSelectorAndLinkCard(stores, activeStore),
                    const SizedBox(height: 14),
                    _buildMetricsGrid(summary),
                    const SizedBox(height: 16),
                    _buildReadOnlyNotice(),
                    const SizedBox(height: 14),
                    _buildFilterSection(),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Riwayat Donasi (${filtered.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_statusFilter != 'all' || _sourceFilter != 'all')
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _statusFilter = 'all';
                                _sourceFilter = 'all';
                              });
                            },
                            child: const Text('Reset Filter'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (filtered.isEmpty)
                      _buildEmptyState()
                    else
                      ...filtered.map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildDonationDetailCard(d),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoreSelectorAndLinkCard(
    List<AssignedStoreInfo> stores,
    AssignedStoreInfo activeStore,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Toko UMK Binaan',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<AssignedStoreInfo>(
                isExpanded: true,
                value: activeStore,
                items: stores.map((store) {
                  return DropdownMenuItem<AssignedStoreInfo>(
                    value: store,
                    child: Row(
                      children: [
                        Icon(Icons.store, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            store.storeName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newStore) {
                  if (newStore == null) return;
                  ref.read(selectedStoreProvider.notifier).selectStore(newStore);
                  setState(() {
                    _selectedStoreIdOverride = newStore.storeId;
                  });
                },
              ),
            ),
            const Divider(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _copyStoreDonationLink(activeStore.storeId),
                icon: const Icon(Icons.link, size: 16),
                label: const Text(
                  'Salin Link Halaman Donasi Toko',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(Map<String, dynamic> summary) {
    final totalCollected = (summary['total_collected'] as num?)?.toInt() ?? 0;
    final totalDistributed =
        (summary['total_distributed'] as num?)?.toInt() ?? 0;
    final pendingDistribution =
        (summary['pending_distribution'] as num?)?.toInt() ?? 0;
    final donorCount = (summary['donor_count'] as num?)?.toInt() ?? 0;
    final contentCount =
        (summary['content_triggered_count'] as num?)?.toInt() ?? 0;
    final contentAmount =
        (summary['content_triggered_amount'] as num?)?.toInt() ?? 0;
    final pendingPaymentCount =
        (summary['pending_payment_count'] as num?)?.toInt() ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Donasi Terkumpul',
                value: CurrencyFormatter.format(totalCollected),
                sub: '$donorCount transaksi lunas',
                color: AppColors.primaryHover,
                icon: Icons.volunteer_activism,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                label: 'Sudah Disalurkan',
                value: CurrencyFormatter.format(totalDistributed),
                sub: 'Diterima UKM Binaan',
                color: AppColors.primary,
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Siap Disalurkan',
                value: CurrencyFormatter.format(pendingDistribution),
                sub: 'Menunggu penyaluran Admin',
                color: const Color(0xFFC2410C),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                label: 'Dari Konten UMK',
                value: '$contentCount Donasi',
                sub:
                    '${CurrencyFormatter.format(contentAmount)} · $pendingPaymentCount pending',
                color: Colors.orange.shade800,
                icon: Icons.campaign_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String sub,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.primaryHover),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tampilan pemantauan read-only. Penyaluran dana donasi dari status Paid ke Disalurkan dikelola oleh Admin.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9A3412)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filter Status',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Semua',
                selected: _statusFilter == 'all',
                onTap: () => setState(() => _statusFilter = 'all'),
              ),
              _buildFilterChip(
                label: 'Siap Salur (Paid)',
                selected: _statusFilter == 'paid',
                onTap: () => setState(() => _statusFilter = 'paid'),
              ),
              _buildFilterChip(
                label: 'Sudah Disalurkan',
                selected: _statusFilter == 'distributed',
                onTap: () => setState(() => _statusFilter = 'distributed'),
              ),
              _buildFilterChip(
                label: 'Menunggu Bayar (Pending)',
                selected: _statusFilter == 'pending',
                onTap: () => setState(() => _statusFilter = 'pending'),
              ),
              _buildFilterChip(
                label: 'Kadaluarsa/Batal',
                selected: _statusFilter == 'expired_or_failed',
                onTap: () =>
                    setState(() => _statusFilter = 'expired_or_failed'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Sumber Donasi',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Semua Sumber',
                selected: _sourceFilter == 'all',
                onTap: () => setState(() => _sourceFilter = 'all'),
              ),
              _buildFilterChip(
                label: 'Dari Konten UMK',
                selected: _sourceFilter == 'content',
                onTap: () => setState(() => _sourceFilter = 'content'),
              ),
              _buildFilterChip(
                label: 'Donasi Langsung Toko',
                selected: _sourceFilter == 'direct',
                onTap: () => setState(() => _sourceFilter = 'direct'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        selectedColor: AppColors.primary.withAlpha(35),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.volunteer_activism_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          const Text(
            'Belum Ada Data Donasi Sesuai Filter',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Bagikan link halaman donasi toko atau sisipkan pada konten promosi/kisah UMK untuk menjangkau donatur.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationDetailCard(BuyerDonationRecord d) {
    final isDistributed = d.status == 'distributed';
    final isPaid = d.status == 'paid';
    final isPending = d.status == 'pending';

    Color badgeBg;
    Color badgeFg;
    if (isDistributed) {
      badgeBg = Colors.green.shade50;
      badgeFg = Colors.green.shade800;
    } else if (isPaid) {
      badgeBg = AppColors.primaryLight;
      badgeFg = AppColors.primaryHover;
    } else if (isPending) {
      badgeBg = Colors.orange.shade50;
      badgeFg = Colors.orange.shade900;
    } else {
      badgeBg = Colors.red.shade50;
      badgeFg = Colors.red.shade800;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    d.donorName,
                    style: const TextStyle(
                      fontSize: 15,
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
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    d.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(d.amount),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.pink.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Waktu: ${DateFormatter.format(d.createdAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            if (d.donorPhone != null && d.donorPhone!.isNotEmpty)
              Text(
                'Kontak: ${d.donorPhone}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            if (d.donorEmail != null && d.donorEmail!.isNotEmpty)
              Text(
                'Email: ${d.donorEmail}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            if (d.paymentChannel != null || d.donationNumber != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (d.paymentChannel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        d.paymentChannelShortLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ),
                  if (d.donationNumber != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        d.donationNumber!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (d.contentId != null && d.contentId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 16,
                      color: Colors.orange.shade900,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pemicu: Konten ${d.contentTitle ?? d.contentId}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Salin Link Donasi Konten Ini',
                      icon: Icon(
                        Icons.copy,
                        size: 15,
                        color: Colors.orange.shade900,
                      ),
                      onPressed: () =>
                          _copyContentDonationLink(d.storeId, d.contentId!),
                    ),
                  ],
                ),
              ),
            ],
            if (d.note != null && d.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '"${d.note}"',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
            if (isDistributed) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Info Penyaluran Admin',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tanggal: ${d.distributedAt != null ? DateFormatter.format(d.distributedAt!) : "-"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade800,
                      ),
                    ),
                    Text(
                      'Nominal Disalurkan: ${CurrencyFormatter.format(d.distributedAmount ?? d.amount)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
