import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/utils/currency_formatter.dart';

class BuyerDonationRecord {
  final String id;
  final String storeId;
  final String? storeName;
  final String? contentId;
  final String? contentTitle;
  final int amount;
  final String donorName;
  final String? note;
  final String status;
  final DateTime createdAt;

  bool get canModify => status != 'distributed';

  BuyerDonationRecord({
    required this.id,
    required this.storeId,
    this.storeName,
    this.contentId,
    this.contentTitle,
    required this.amount,
    required this.donorName,
    this.note,
    required this.status,
    required this.createdAt,
  });

  factory BuyerDonationRecord.fromMap(Map<String, dynamic> map) {
    final store = map['stores'] as Map<String, dynamic>?;
    final content = map['store_contents'] as Map<String, dynamic>?;
    return BuyerDonationRecord(
      id: map['id'] as String? ?? '',
      storeId: map['store_id'] as String? ?? '',
      storeName: store?['name'] as String?,
      contentId: map['content_id'] as String?,
      contentTitle: content?['title'] as String?,
      amount: (map['amount'] as num?)?.round() ?? 0,
      donorName: map['donor_name'] as String? ?? 'Hamba Allah (Anonim)',
      note: map['note'] as String?,
      status: map['status'] as String? ?? 'paid',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class BuyerDonationService {
  Future<List<BuyerDonationRecord>> getMyDonations() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('donations')
          .select('''
            *,
            stores (
              name
            ),
            store_contents (
              title
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (e) => BuyerDonationRecord.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (_) {
      final fallback = await supabase
          .from('donations')
          .select('''
            *,
            stores (
              name
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (fallback as List<dynamic>)
          .map(
            (e) => BuyerDonationRecord.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }
  }

  Future<void> createDonation({
    required String storeId,
    String? contentId,
    required int amount,
    required String donorName,
    String? note,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Silakan login terlebih dahulu untuk berdonasi.');
    }

    final payload = <String, dynamic>{
      'user_id': user.id,
      'store_id': storeId,
      'amount': amount,
      'donor_name': donorName.trim().isEmpty
          ? 'Hamba Allah (Anonim)'
          : donorName.trim(),
      'donor_email': user.email,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'status': 'paid',
    };

    if (contentId != null && contentId.isNotEmpty) {
      payload['content_id'] = contentId;
    }

    await supabase.from('donations').insert(payload);
  }

  Future<void> updateDonation({
    required String donationId,
    required int amount,
    required String donorName,
    String? note,
  }) async {
    await supabase
        .from('donations')
        .update({
          'amount': amount,
          'donor_name': donorName.trim().isEmpty
              ? 'Hamba Allah (Anonim)'
              : donorName.trim(),
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', donationId);
  }

  Future<void> deleteDonation(String donationId) async {
    await supabase.from('donations').delete().eq('id', donationId);
  }
}

final buyerDonationServiceProvider = Provider<BuyerDonationService>((ref) {
  return BuyerDonationService();
});

final myDonationsProvider =
    FutureProvider.autoDispose<List<BuyerDonationRecord>>((ref) async {
      final service = ref.watch(buyerDonationServiceProvider);
      return service.getMyDonations();
    });

Future<bool?> showBuyerDonationDialog(
  BuildContext context,
  WidgetRef ref, {
  required String storeId,
  required String storeName,
  String? contentId,
  String? contentTitle,
  BuyerDonationRecord? existingDonation,
}) {
  final amountCtrl = TextEditingController(
    text: (existingDonation?.amount ?? 25000).toString(),
  );
  final donorNameCtrl = TextEditingController(
    text: existingDonation?.donorName ?? 'Hamba Allah (Anonim)',
  );
  final noteCtrl = TextEditingController(
    text:
        existingDonation?.note ??
        (contentTitle != null ? 'Dukungan dari konten: $contentTitle' : ''),
  );
  final presetAmounts = [10000, 25000, 50000, 100000];

  return showDialog<bool>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final currentVal = int.tryParse(amountCtrl.text.trim()) ?? 0;

          return AlertDialog(
            title: Text(
              existingDonation == null
                  ? 'Donasi ke $storeName'
                  : 'Edit Donasi UMK',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (contentTitle != null && contentTitle.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.pink.shade100),
                      ),
                      child: Text(
                        'Konten UMK: "$contentTitle"',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.pink.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Pilih Nominal Cepat:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presetAmounts.map((preset) {
                      final isSelected = currentVal == preset;
                      return ChoiceChip(
                        label: Text(
                          CurrencyFormatter.format(preset),
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          setStateDialog(() {
                            amountCtrl.text = preset.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setStateDialog(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Nominal Donasi (Rp) *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: donorNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Donatur',
                      hintText: 'Hamba Allah (Anonim)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Pesan / Dukungan untuk UMK',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (amount < 1000) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nominal donasi minimal Rp 1.000.'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogCtx, true);
                  try {
                    final service = ref.read(buyerDonationServiceProvider);
                    if (existingDonation == null) {
                      await service.createDonation(
                        storeId: storeId,
                        contentId: contentId,
                        amount: amount,
                        donorName: donorNameCtrl.text,
                        note: noteCtrl.text,
                      );
                    } else {
                      await service.updateDonation(
                        donationId: existingDonation.id,
                        amount: amount,
                        donorName: donorNameCtrl.text,
                        note: noteCtrl.text,
                      );
                    }

                    ref.invalidate(myDonationsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            existingDonation == null
                                ? 'Terima kasih! Donasi ${CurrencyFormatter.format(amount)} untuk $storeName berhasil tercatat.'
                                : 'Donasi berhasil diperbarui.',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal memproses donasi: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.volunteer_activism, size: 16),
                label: Text(
                  existingDonation == null ? 'Kirim Donasi' : 'Simpan',
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
