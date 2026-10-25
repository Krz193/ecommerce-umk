import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/donation/services/buyer_donation_service.dart';

class BuyerDonationsPage extends ConsumerWidget {
  const BuyerDonationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donationsAsync = ref.watch(myDonationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donasi UMK Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myDonationsProvider),
          ),
        ],
      ),
      body: donationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal memuat riwayat donasi: $err'),
          ),
        ),
        data: (donations) {
          final totalDonated = donations.fold<int>(
            0,
            (sum, d) => sum + d.amount,
          );
          final uniqueStores = donations.map((d) => d.storeId).toSet().length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myDonationsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.pink.shade700, Colors.orange.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Donasi Anda ke UMK',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(totalDonated),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${donations.length} Donasi · $uniqueStores UMK',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (donations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(
                          Icons.volunteer_activism_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum Ada Riwayat Donasi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Anda dapat berdonasi langsung saat melihat konten kisah atau promosi UMK di halaman Jelajah maupun Profil Toko.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...donations.map(
                    (donation) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDonationCard(context, ref, donation),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDonationCard(
    BuildContext context,
    WidgetRef ref,
    BuyerDonationRecord donation,
  ) {
    final isDistributed = donation.status == 'distributed';

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
                    donation.storeName ?? 'Toko UMK',
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
                    color: isDistributed
                        ? Colors.green.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isDistributed ? 'Telah Disalurkan' : 'Tercatat (Paid)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDistributed
                          ? Colors.green.shade800
                          : Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              CurrencyFormatter.format(donation.amount),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.pink.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Donatur: ${donation.donorName} · ${DateFormatter.format(donation.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (donation.contentTitle != null &&
                donation.contentTitle!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Dari Konten: ${donation.contentTitle}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
            if (donation.note != null && donation.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '"${donation.note}"',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
            if (donation.canModify) ...[
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      showBuyerDonationDialog(
                        context,
                        ref,
                        storeId: donation.storeId,
                        storeName: donation.storeName ?? 'Toko UMK',
                        contentId: donation.contentId,
                        contentTitle: donation.contentTitle,
                        existingDonation: donation,
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit Donasi'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    onPressed: () => _confirmDelete(context, ref, donation),
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: const Text('Batalkan'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BuyerDonationRecord donation,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Batalkan / Hapus Donasi?'),
        content: Text(
          'Hapus donasi sebesar ${CurrencyFormatter.format(donation.amount)} untuk ${donation.storeName ?? "Toko UMK"}?',
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
                await ref
                    .read(buyerDonationServiceProvider)
                    .deleteDonation(donation.id);
                ref.invalidate(myDonationsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Donasi berhasil dibatalkan/dihapus.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus donasi: $e')),
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
