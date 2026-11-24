import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          final settledDonations =
              donations.where((d) => d.isSettledOrDistributed).toList();
          final totalDonated = settledDonations.fold<int>(
            0,
            (sum, d) => sum + d.amount,
          );
          final uniqueStores =
              settledDonations.map((d) => d.storeId).toSet().length;
          final pendingCount =
              donations.where((d) => d.status == 'pending').length;

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
                            'Total Donasi Lunas ke UMK',
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
                          if (pendingCount > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              '$pendingCount tagihan VA/QRIS menunggu pembayaran',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
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
                          '${settledDonations.length} Lunas · $uniqueStores UMK',
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
    final isPaid = donation.status == 'paid';
    final isPendingActive = donation.isPendingActive;

    Color badgeBg;
    Color badgeFg;
    if (isDistributed) {
      badgeBg = Colors.green.shade50;
      badgeFg = Colors.green.shade800;
    } else if (isPaid) {
      badgeBg = Colors.blue.shade50;
      badgeFg = Colors.blue.shade800;
    } else if (isPendingActive) {
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
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    donation.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeFg,
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
            if (donation.donationNumber != null ||
                donation.paymentChannel != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (donation.paymentChannel != null)
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
                        donation.paymentChannelShortLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ),
                  if (donation.donationNumber != null)
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
                        donation.donationNumber!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (isPendingActive &&
                donation.vaNumber != null &&
                donation.vaNumber!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'VA: ${donation.vaNumber}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
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
            if (isDistributed) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Disalurkan ke toko pada ${donation.distributedAt != null ? DateFormatter.format(donation.distributedAt!) : "-"} sebesar ${CurrencyFormatter.format(donation.distributedAmount ?? donation.amount)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
            const Divider(height: 18),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isPendingActive) ...[
                  ElevatedButton.icon(
                    onPressed: () => _openPaymentPage(
                      context,
                      ref,
                      donation,
                      editMode: false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.qr_code_2, size: 16),
                    label: const Text('Lihat VA / Bayar Sekarang'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openPaymentPage(
                      context,
                      ref,
                      donation,
                      editMode: true,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Ubah / Ganti Bank'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    onPressed: () => _confirmDelete(context, ref, donation),
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: const Text('Batalkan'),
                  ),
                ] else if (donation.canChangePaymentOrCancel) ...[
                  ElevatedButton.icon(
                    onPressed: () => _openPaymentPage(
                      context,
                      ref,
                      donation,
                      editMode: true,
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Generate Ulang VA'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    onPressed: () => _confirmDelete(context, ref, donation),
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: const Text('Hapus'),
                  ),
                ] else if (isPaid) ...[
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showEditDonorInfoDialog(context, ref, donation),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit Nama / Pesan Doa'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openPaymentPage(
                      context,
                      ref,
                      donation,
                      editMode: false,
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 15),
                    label: const Text('Detail Pembayaran'),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: () => _openPaymentPage(
                      context,
                      ref,
                      donation,
                      editMode: false,
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 15),
                    label: const Text('Detail Pembayaran'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPaymentPage(
    BuildContext context,
    WidgetRef ref,
    BuyerDonationRecord donation, {
    required bool editMode,
  }) async {
    final route = buildInternalDonationRoute(
      storeId: donation.storeId,
      storeName: donation.storeName,
      contentId: donation.contentId,
      contentTitle: donation.contentTitle,
      donationId: donation.id,
      editMode: editMode,
    );
    await context.push(route, extra: donation);
    ref.invalidate(myDonationsProvider);
  }

  void _showEditDonorInfoDialog(
    BuildContext context,
    WidgetRef ref,
    BuyerDonationRecord donation,
  ) {
    final nameCtrl = TextEditingController(text: donation.donorName);
    final noteCtrl = TextEditingController(text: donation.note ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit Nama & Pesan Doa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Donasi sudah lunas sehingga nominal dan metode pembayaran terkunci.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Donatur',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Pesan / Doa untuk UMK',
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
              try {
                await ref
                    .read(buyerDonationServiceProvider)
                    .updateDonorInfo(
                      donationId: donation.id,
                      donorName: nameCtrl.text,
                      note: noteCtrl.text,
                    );
                ref.invalidate(myDonationsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Info donatur & pesan berhasil diperbarui.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal memperbarui: $e')),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
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
          'Hapus tagihan donasi sebesar ${CurrencyFormatter.format(donation.amount)} untuk ${donation.storeName ?? "Toko UMK"}?',
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
