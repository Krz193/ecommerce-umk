import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/donation/services/buyer_donation_service.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher/url_launcher.dart';

class DonationPaymentPage extends ConsumerStatefulWidget {
  final String storeId;
  final String? storeName;
  final String? contentId;
  final String? contentTitle;
  final String? donationId;
  final bool editMode;
  final BuyerDonationRecord? initialDonation;

  const DonationPaymentPage({
    super.key,
    required this.storeId,
    this.storeName,
    this.contentId,
    this.contentTitle,
    this.donationId,
    this.editMode = false,
    this.initialDonation,
  });

  @override
  ConsumerState<DonationPaymentPage> createState() =>
      _DonationPaymentPageState();
}

class _DonationPaymentPageState extends ConsumerState<DonationPaymentPage> {
  final _amountCtrl = TextEditingController(text: '25000');
  final _donorNameCtrl = TextEditingController(text: 'Hamba Allah (Anonim)');
  final _noteCtrl = TextEditingController();

  String _selectedChannel = 'bca';
  bool _useAnonymous = false;
  String? _profileName;

  String _effectiveStoreId = '';
  String? _resolvedStoreName;
  String? _effectiveContentId;
  String? _resolvedContentTitle;

  BuyerDonationRecord? _activeDonation;
  bool _isEditingForm = true;
  bool _isLoadingInitial = false;
  bool _isGenerating = false;
  bool _isCheckingStatus = false;

  Timer? _countdownTimer;
  Timer? _pollingTimer;
  Duration _remainingTime = Duration.zero;

  static const List<int> _presetAmounts = [10000, 25000, 50000, 100000];

  @override
  void initState() {
    super.initState();
    _effectiveStoreId = widget.initialDonation?.storeId ?? widget.storeId;
    _resolvedStoreName = widget.initialDonation?.storeName ?? widget.storeName;
    _effectiveContentId = widget.initialDonation?.contentId ?? widget.contentId;
    _resolvedContentTitle =
        widget.initialDonation?.contentTitle ?? widget.contentTitle;

    if (widget.initialDonation != null) {
      _applyDonationToState(widget.initialDonation!, editMode: widget.editMode);
    } else if (widget.donationId != null && widget.donationId!.isNotEmpty) {
      _loadDonationById(widget.donationId!);
    } else {
      if (_resolvedContentTitle != null && _resolvedContentTitle!.isNotEmpty) {
        _noteCtrl.text = 'Dukungan dari konten: $_resolvedContentTitle';
      }
      _loadInitialMetadata();
    }
  }

  @override
  void dispose() {
    _stopTimers();
    _amountCtrl.dispose();
    _donorNameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _startTimersIfPending() {
    _stopTimers();
    final donation = _activeDonation;
    if (donation == null || donation.status != 'pending') return;

    _updateRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
    });
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkPaymentStatus(silent: true);
    });
  }

  void _updateRemainingTime() {
    final donation = _activeDonation;
    if (donation == null || donation.expiredAt == null) return;

    final diff = donation.expiredAt!.toLocal().difference(DateTime.now());
    if (!mounted) return;

    if (diff.isNegative) {
      setState(() {
        _remainingTime = Duration.zero;
        if (donation.status == 'pending') {
          _activeDonation = BuyerDonationRecord(
            id: donation.id,
            userId: donation.userId,
            storeId: donation.storeId,
            storeName: donation.storeName,
            contentId: donation.contentId,
            contentTitle: donation.contentTitle,
            contentType: donation.contentType,
            donationNumber: donation.donationNumber,
            amount: donation.amount,
            donorName: donation.donorName,
            donorPhone: donation.donorPhone,
            donorEmail: donation.donorEmail,
            note: donation.note,
            status: 'expired',
            paymentType: donation.paymentType,
            paymentChannel: donation.paymentChannel,
            vaNumber: donation.vaNumber,
            billerCode: donation.billerCode,
            qrUrl: donation.qrUrl,
            deeplinkUrl: donation.deeplinkUrl,
            expiredAt: donation.expiredAt,
            paidAt: donation.paidAt,
            distributedAt: donation.distributedAt,
            distributedAmount: donation.distributedAmount,
            createdAt: donation.createdAt,
          );
          _stopTimers();
        }
      });
      return;
    }

    setState(() {
      _remainingTime = diff;
    });
  }

  Future<void> _loadInitialMetadata() async {
    final service = ref.read(buyerDonationServiceProvider);
    try {
      final profileFuture = service.getCurrentUserFullName();
      final needsLabels =
          _resolvedStoreName == null ||
          _resolvedStoreName!.isEmpty ||
          (_effectiveContentId != null &&
              _effectiveContentId!.isNotEmpty &&
              (_resolvedContentTitle == null || _resolvedContentTitle!.isEmpty));

      final labelsFuture = needsLabels
          ? service.resolveStoreAndContentLabels(
              storeId: _effectiveStoreId,
              contentId: _effectiveContentId,
            )
          : Future.value(<String, String?>{});

      final profileName = await profileFuture;
      final labels = await labelsFuture;
      if (!mounted) return;

      setState(() {
        _profileName = profileName;
        if (!_useAnonymous && profileName != null && profileName.isNotEmpty) {
          _donorNameCtrl.text = profileName;
        }
        if ((_resolvedStoreName == null || _resolvedStoreName!.isEmpty) &&
            labels['storeName'] != null) {
          _resolvedStoreName = labels['storeName'];
        }
        if ((_resolvedContentTitle == null || _resolvedContentTitle!.isEmpty) &&
            labels['contentTitle'] != null) {
          _resolvedContentTitle = labels['contentTitle'];
          if (_noteCtrl.text.trim().isEmpty) {
            _noteCtrl.text = 'Dukungan dari konten: $_resolvedContentTitle';
          }
        }
      });
    } catch (_) {
      // Non-fatal metadata enrichment
    }
  }

  Future<void> _loadDonationById(String donationId) async {
    setState(() => _isLoadingInitial = true);
    try {
      final service = ref.read(buyerDonationServiceProvider);
      final record = await service.getDonationById(donationId);
      if (!mounted) return;
      if (record != null) {
        _applyDonationToState(record, editMode: widget.editMode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat data donasi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  void _applyDonationToState(
    BuyerDonationRecord donation, {
    required bool editMode,
  }) {
    _effectiveStoreId = donation.storeId;
    _resolvedStoreName = donation.storeName ?? _resolvedStoreName;
    _effectiveContentId = donation.contentId ?? _effectiveContentId;
    _resolvedContentTitle = donation.contentTitle ?? _resolvedContentTitle;

    _amountCtrl.text = donation.amount.toString();
    _donorNameCtrl.text = donation.donorName;
    _useAnonymous = donation.donorName.toLowerCase().contains('hamba allah');
    _noteCtrl.text = donation.note ?? '';
    if (donation.paymentChannel != null && donation.paymentChannel!.isNotEmpty) {
      _selectedChannel = donation.paymentChannel!.toLowerCase();
    }

    _activeDonation = donation;
    final hasPaymentArtifacts =
        (donation.vaNumber != null && donation.vaNumber!.isNotEmpty) ||
        (donation.qrUrl != null && donation.qrUrl!.isNotEmpty) ||
        (donation.deeplinkUrl != null && donation.deeplinkUrl!.isNotEmpty) ||
        donation.status == 'paid' ||
        donation.status == 'distributed';

    _isEditingForm = editMode && donation.canChangePaymentOrCancel
        ? true
        : !hasPaymentArtifacts;

    if (!_isEditingForm && donation.status == 'pending') {
      _startTimersIfPending();
    } else {
      _stopTimers();
    }
  }

  Future<void> _generatePayment() async {
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal donasi minimal Rp 1.000.')),
      );
      return;
    }

    if (_effectiveStoreId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toko UMK tujuan belum dipilih.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final service = ref.read(buyerDonationServiceProvider);
      final donorName = _useAnonymous
          ? 'Hamba Allah (Anonim)'
          : _donorNameCtrl.text.trim();

      final result = await service.generateDonationPayment(
        donationId: _activeDonation?.canChangePaymentOrCancel == true
            ? _activeDonation?.id
            : null,
        storeId: _effectiveStoreId,
        contentId: _effectiveContentId,
        amount: amount,
        donorName: donorName,
        note: _noteCtrl.text.trim(),
        paymentChannel: _selectedChannel,
      );

      final rawDonation = result['donation'] as Map<String, dynamic>?;
      if (rawDonation == null) {
        throw Exception('Respons data donasi dari server kosong.');
      }

      final updatedRecord = BuyerDonationRecord.fromMap(rawDonation);
      ref.invalidate(myDonationsProvider);

      if (!mounted) return;
      setState(() {
        _activeDonation = updatedRecord;
        _isEditingForm = false;
      });
      _startTimersIfPending();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tagihan ${updatedRecord.paymentChannelShortLabel} berhasil dibuat!',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat pembayaran: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _checkPaymentStatus({bool silent = false}) async {
    final donation = _activeDonation;
    if (donation == null || _isCheckingStatus) return;

    if (!silent) {
      setState(() => _isCheckingStatus = true);
    }

    try {
      final service = ref.read(buyerDonationServiceProvider);
      final res = await service.checkDonationPaymentStatus(donation.id);

      if (!mounted) return;

      final rawDonation = res['donation'] as Map<String, dynamic>?;
      final latestRecord = rawDonation != null
          ? BuyerDonationRecord.fromMap(rawDonation)
          : donation;

      final prevStatus = donation.status;
      setState(() {
        _activeDonation = latestRecord;
      });

      if (latestRecord.status == 'paid' ||
          latestRecord.status == 'distributed' ||
          latestRecord.status == 'expired' ||
          latestRecord.status == 'failed') {
        _stopTimers();
        ref.invalidate(myDonationsProvider);
      }

      if (latestRecord.status == 'paid' && prevStatus != 'paid') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alhamdulillah! Pembayaran donasi telah berhasil.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status saat ini: ${latestRecord.statusLabel}')),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memeriksa status: $e')));
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  Future<void> _copyShareLink() async {
    if (_effectiveStoreId.trim().isEmpty) return;
    final link = buildDonationPageLink(
      storeId: _effectiveStoreId,
      storeName: _resolvedStoreName,
      contentId: _effectiveContentId,
      contentTitle: _resolvedContentTitle,
    );
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link halaman donasi disalin: $link'),
      ),
    );
  }

  Future<void> _copyText(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label berhasil disalin')));
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditingForm ? 'Donasi ke UMK' : 'Pembayaran Donasi',
        ),
        actions: [
          if (_effectiveStoreId.trim().isNotEmpty)
            IconButton(
              icon: const Icon(Icons.link_rounded),
              tooltip: 'Salin Link Halaman Donasi',
              onPressed: _copyShareLink,
            ),
        ],
      ),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator())
          : _isEditingForm || _activeDonation == null
          ? _buildFormView()
          : _buildPaymentView(_activeDonation!),
    );
  }

  Widget _buildShareLinkCard() {
    if (_effectiveStoreId.trim().isEmpty) return const SizedBox.shrink();
    final link = buildDonationPageLink(
      storeId: _effectiveStoreId,
      contentId: _effectiveContentId,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.share_outlined, color: Colors.teal.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bagikan Link Halaman Donasi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.teal.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _copyShareLink,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.teal.shade800,
              side: BorderSide(color: Colors.teal.shade400),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Salin Link', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _resolvedStoreName ?? 'Toko UMK Binaan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (_resolvedContentTitle != null &&
              _resolvedContentTitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Dari Konten: $_resolvedContentTitle',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Pilih nominal dan metode VA Bank atau E-Wallet/QRIS untuk langsung menghasilkan nomor pembayaran resmi Midtrans.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    final currentAmount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    final vaChannels =
        donationPaymentChannels.where((c) => c.category == 'va').toList();
    final ewalletChannels =
        donationPaymentChannels.where((c) => c.category == 'ewallet').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTargetBanner(),
        const SizedBox(height: 12),
        _buildShareLinkCard(),
        const SizedBox(height: 16),

        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Nominal Donasi',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetAmounts.map((preset) {
                    final selected = currentAmount == preset;
                    return ChoiceChip(
                      label: Text(CurrencyFormatter.format(preset)),
                      selected: selected,
                      selectedColor: Colors.teal.shade100,
                      onSelected: (_) {
                        setState(() {
                          _amountCtrl.text = preset.toString();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Nominal Donasi (Rp) *',
                    helperText: 'Minimal Rp 1.000',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2. Identitas Donatur & Pesan Dukungan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Donasi sebagai Anonim (Hamba Allah)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  value: _useAnonymous,
                  onChanged: (val) {
                    setState(() {
                      _useAnonymous = val;
                      if (val) {
                        _donorNameCtrl.text = 'Hamba Allah (Anonim)';
                      } else if (_profileName != null &&
                          _profileName!.isNotEmpty) {
                        _donorNameCtrl.text = _profileName!;
                      } else {
                        _donorNameCtrl.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _donorNameCtrl,
                  enabled: !_useAnonymous,
                  decoration: const InputDecoration(
                    labelText: 'Nama Donatur',
                    hintText: 'Hamba Allah (Anonim)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Pesan / Doa untuk UMK (Opsional)',
                    hintText: 'Semoga usahanya semakin lancar dan berkah!',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '3. Pilih Bank VA atau E-Wallet / QRIS',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Virtual Account Bank',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                ...vaChannels.map(_buildChannelTile),
                const SizedBox(height: 12),
                Text(
                  'E-Wallet & QRIS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                ...ewalletChannels.map(_buildChannelTile),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generatePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.qr_code_2_rounded),
            label: Text(
              _isGenerating
                  ? 'Membuat Nomor VA / QRIS...'
                  : 'Generate VA / Bayar ${CurrencyFormatter.format(currentAmount)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (_activeDonation != null && !_isGenerating) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() => _isEditingForm = false);
              _startTimersIfPending();
            },
            child: const Text('Kembali ke Tagihan Sebelumnya'),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildChannelTile(DonationPaymentChannelOption option) {
    final isSelected = _selectedChannel == option.code;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedChannel = option.code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.teal.shade600 : Colors.grey.shade300,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? Colors.teal.shade700 : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSelected
                            ? Colors.teal.shade900
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentView(BuyerDonationRecord donation) {
    final status = donation.status;
    final isPaidOrDistributed =
        status == 'paid' || status == 'distributed';
    final isPending = status == 'pending';

    return RefreshIndicator(
      onRefresh: () => _checkPaymentStatus(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildShareLinkCard(),
          const SizedBox(height: 14),

          if (isPaidOrDistributed)
            _buildSuccessReceiptCard(donation)
          else if (isPending)
            _buildPendingPaymentCard(donation)
          else
            _buildExpiredOrFailedCard(donation),
        ],
      ),
    );
  }

  Widget _buildSuccessReceiptCard(BuyerDonationRecord donation) {
    final isDistributed = donation.status == 'distributed';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 12),
            Text(
              isDistributed
                  ? 'Donasi Telah Disalurkan ke UMK'
                  : 'Pembayaran Donasi Berhasil!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              CurrencyFormatter.format(donation.amount),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(),
            _buildSummaryRow('Toko Tujuan', donation.storeName ?? 'Toko UMK'),
            if (donation.donationNumber != null)
              _buildSummaryRow('Nomor Transaksi', donation.donationNumber!),
            _buildSummaryRow('Metode', donation.paymentChannelLabel),
            _buildSummaryRow('Nama Donatur', donation.donorName),
            if (donation.paidAt != null)
              _buildSummaryRow(
                'Waktu Lunas',
                '${DateFormatter.format(donation.paidAt!)} WIB',
              ),
            if (isDistributed && donation.distributedAt != null)
              _buildSummaryRow(
                'Disalurkan Admin',
                '${DateFormatter.format(donation.distributedAt!)} (${CurrencyFormatter.format(donation.distributedAmount ?? donation.amount)})',
              ),
            if (donation.note != null && donation.note!.isNotEmpty)
              _buildSummaryRow('Pesan / Doa', donation.note!),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/donations'),
                child: const Text('Lihat Riwayat Donasi Saya'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.pop(true),
                child: const Text('Kembali'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingPaymentCard(BuyerDonationRecord donation) {
    final isMandiri = donation.paymentChannel == 'mandiri';
    final hasQrImage =
        donation.qrUrl != null && donation.qrUrl!.startsWith('http');
    final hasQrString =
        donation.qrUrl != null && !donation.qrUrl!.startsWith('http');
    final hasDeeplink =
        donation.deeplinkUrl != null && donation.deeplinkUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              const Text(
                'Selesaikan Pembayaran Sebelum',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                _formatDuration(_remainingTime),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
              if (donation.expiredAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Batas waktu: ${DateFormatter.format(donation.expiredAt!)} WIB',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donation.paymentChannelLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tujuan: ${donation.storeName ?? _resolvedStoreName ?? "Toko UMK"}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                if (donation.donationNumber != null)
                  Text(
                    'Ref: ${donation.donationNumber}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Total Donasi',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        CurrencyFormatter.format(donation.amount),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () =>
                          _copyText(donation.amount.toString(), 'Nominal'),
                    ),
                  ],
                ),
                const Divider(height: 20),

                if (isMandiri && donation.billerCode != null) ...[
                  const Text(
                    'Kode Perusahaan (Biller Code)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          donation.billerCode!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () =>
                            _copyText(donation.billerCode!, 'Biller Code'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                if (donation.vaNumber != null &&
                    donation.vaNumber!.isNotEmpty) ...[
                  Text(
                    isMandiri
                        ? 'Kode Pembayaran (Bill Key)'
                        : 'Nomor Virtual Account',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          donation.vaNumber!,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _copyText(
                          donation.vaNumber!,
                          isMandiri ? 'Bill Key' : 'Nomor VA',
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Salin'),
                      ),
                    ],
                  ),
                ],

                if (hasQrImage) ...[
                  const Text(
                    'Scan QR Code untuk Membayar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Image.network(
                        donation.qrUrl!,
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox(
                          height: 120,
                          child: Center(
                            child: Text('Gambar QR tidak dapat dimuat'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          _copyText(donation.qrUrl!, 'URL QR Code'),
                      icon: const Icon(Icons.copy, size: 15),
                      label: const Text('Salin URL QR'),
                    ),
                  ),
                ],

                if (hasQrString) ...[
                  const Text(
                    'Kode QRIS String',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    donation.qrUrl!,
                    style: const TextStyle(fontSize: 12),
                  ),
                  TextButton.icon(
                    onPressed: () => _copyText(donation.qrUrl!, 'QR String'),
                    icon: const Icon(Icons.copy, size: 15),
                    label: const Text('Salin QR String'),
                  ),
                ],

                if (hasDeeplink) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final uri = Uri.tryParse(donation.deeplinkUrl!);
                        if (uri != null) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(
                        'Buka Aplikasi ${donation.paymentChannelShortLabel}',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildPaymentInstructionsCard(donation),
        const SizedBox(height: 16),
        SizedBox(
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _isCheckingStatus ? null : () => _checkPaymentStatus(),
            icon: _isCheckingStatus
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(
              _isCheckingStatus
                  ? 'Memeriksa Status...'
                  : 'Cek Status Pembayaran',
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            _stopTimers();
            setState(() => _isEditingForm = true);
          },
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Ubah Nominal / Ganti Bank VA / E-Wallet'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildExpiredOrFailedCard(BuyerDonationRecord donation) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.access_time_filled, color: Colors.red, size: 64),
            const SizedBox(height: 12),
            Text(
              'Tagihan ${donation.statusLabel}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Donasi sebesar ${CurrencyFormatter.format(donation.amount)} untuk ${donation.storeName ?? "Toko UMK"} belum diselesaikan sebelum batas waktu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _isEditingForm = true),
                icon: const Icon(Icons.refresh),
                label: const Text('Generate Ulang VA / QRIS Baru'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isCheckingStatus
                    ? null
                    : () => _checkPaymentStatus(),
                child: const Text('Cek Ulang Status Midtrans'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInstructionsCard(BuyerDonationRecord donation) {
    final channel = donation.paymentChannel ?? 'bca';
    List<String> steps;

    if (channel == 'mandiri') {
      steps = const [
        '1. Buka aplikasi Livin by Mandiri atau ATM Mandiri.',
        '2. Pilih menu Bayar / Multi Payment.',
        '3. Masukkan Kode Perusahaan (Biller Code) dan Kode Pembayaran (Bill Key) di atas.',
        '4. Periksa nominal donasi dan konfirmasi pembayaran.',
      ];
    } else if (channel == 'qris' ||
        channel == 'gopay' ||
        channel == 'shopeepay') {
      steps = const [
        '1. Buka aplikasi e-wallet (DANA, OVO, GoPay, ShopeePay, LinkAja) atau m-Banking.',
        '2. Pilih Scan QRIS atau tekan tombol Buka Aplikasi di atas.',
        '3. Pastikan penerima & nominal donasi sudah sesuai, lalu selesaikan pembayaran.',
        '4. Status donasi otomatis diperbarui setelah pembayaran terkonfirmasi.',
      ];
    } else {
      steps = const [
        '1. Buka aplikasi mobile banking atau ATM bank pilihan Anda.',
        '2. Pilih menu Transfer ke Virtual Account.',
        '3. Masukkan Nomor Virtual Account di atas.',
        '4. Pastikan nominal donasi sesuai dan selesaikan transaksi sebelum waktu habis.',
      ];
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Panduan Pembayaran',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...steps.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(s, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
