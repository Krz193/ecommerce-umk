import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/store/models/store_model.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class _EditableTierRow {
  final TextEditingController minCtrl;
  final TextEditingController maxCtrl;
  final TextEditingController priceCtrl;

  _EditableTierRow({
    required double minKm,
    required double maxKm,
    required int price,
  }) : minCtrl = TextEditingController(
         text: minKm % 1 == 0 ? minKm.toInt().toString() : minKm.toString(),
       ),
       maxCtrl = TextEditingController(
         text: maxKm % 1 == 0 ? maxKm.toInt().toString() : maxKm.toString(),
       ),
       priceCtrl = TextEditingController(text: price.toString());

  void dispose() {
    minCtrl.dispose();
    maxCtrl.dispose();
    priceCtrl.dispose();
  }
}

class SellerLocalShippingPage extends ConsumerStatefulWidget {
  final String? storeId;

  const SellerLocalShippingPage({super.key, this.storeId});

  @override
  ConsumerState<SellerLocalShippingPage> createState() =>
      _SellerLocalShippingPageState();
}

class _SellerLocalShippingPageState
    extends ConsumerState<SellerLocalShippingPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  StoreModel? _store;

  bool _ojekEnabled = false;
  final List<_EditableTierRow> _ojekRows = [];

  bool _ekspedisiEnabled = false;
  final List<_EditableTierRow> _ekspedisiRows = [];

  List<Map<String, dynamic>> _storeCouriers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final row in _ojekRows) {
      row.dispose();
    }
    for (final row in _ekspedisiRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storeService = ref.read(storeServiceProvider);
      StoreModel? resolvedStore;

      if (widget.storeId != null && widget.storeId!.trim().isNotEmpty) {
        resolvedStore = await storeService.getStoreById(widget.storeId!.trim());
      } else {
        resolvedStore = await ref.read(managedStoreProvider.future);
      }

      if (resolvedStore == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Toko tidak ditemukan.';
          });
        }
        return;
      }

      List<Map<String, dynamic>> couriers = [];
      try {
        couriers = await storeService.getStoreCouriers(resolvedStore.id);
      } catch (_) {}

      if (!mounted) return;

      for (final row in _ojekRows) {
        row.dispose();
      }
      for (final row in _ekspedisiRows) {
        row.dispose();
      }
      _ojekRows.clear();
      _ekspedisiRows.clear();

      for (final tier in resolvedStore.localOjekRates) {
        _ojekRows.add(
          _EditableTierRow(
            minKm: tier.minKm,
            maxKm: tier.maxKm,
            price: tier.price,
          ),
        );
      }

      for (final tier in resolvedStore.localEkspedisiRates) {
        _ekspedisiRows.add(
          _EditableTierRow(
            minKm: tier.minKm,
            maxKm: tier.maxKm,
            price: tier.price,
          ),
        );
      }

      setState(() {
        _store = resolvedStore;
        _ojekEnabled = resolvedStore!.localOjekEnabled;
        _ekspedisiEnabled = resolvedStore.localEkspedisiEnabled;
        _storeCouriers = couriers;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _addTierRow(List<_EditableTierRow> target, {required int defaultPrice}) {
    double nextMin = 0;
    if (target.isNotEmpty) {
      nextMin = double.tryParse(target.last.maxCtrl.text.trim()) ?? 0;
    }
    setState(() {
      target.add(
        _EditableTierRow(
          minKm: nextMin,
          maxKm: nextMin + 5,
          price: defaultPrice,
        ),
      );
    });
  }

  void _removeTierRow(List<_EditableTierRow> target, int index) {
    setState(() {
      final removed = target.removeAt(index);
      removed.dispose();
    });
  }

  ({List<LocalShippingRateTier>? tiers, String? error}) _parseRows(
    List<_EditableTierRow> rows,
    String serviceLabel,
  ) {
    final parsed = <LocalShippingRateTier>[];
    for (var i = 0; i < rows.length; i++) {
      final minVal = double.tryParse(rows[i].minCtrl.text.trim());
      final maxVal = double.tryParse(rows[i].maxCtrl.text.trim());
      final priceVal = int.tryParse(rows[i].priceCtrl.text.trim());

      if (minVal == null || maxVal == null || priceVal == null) {
        return (
          tiers: null,
          error: '$serviceLabel baris #${i + 1}: isi angka jarak & ongkir dengan benar.',
        );
      }
      parsed.add(
        LocalShippingRateTier(minKm: minVal, maxKm: maxVal, price: priceVal),
      );
    }

    final validationError = LocalShippingRateTier.validateTiers(parsed);
    if (validationError != null) {
      return (tiers: null, error: '$serviceLabel: $validationError');
    }

    parsed.sort((a, b) => a.minKm.compareTo(b.minKm));
    return (tiers: parsed, error: null);
  }

  Future<void> _saveSettings() async {
    final store = _store;
    if (store == null) return;

    if ((_ojekEnabled || _ekspedisiEnabled) && !store.hasValidCoordinates) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Atur titik GPS lokasi toko terlebih dahulu agar jarak pengiriman lokal dapat dihitung.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_ojekEnabled && _ojekRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tambahkan minimal 1 range jarak & ongkir untuk Ojek Lokal Toko.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_ekspedisiEnabled && _ekspedisiRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tambahkan minimal 1 range jarak & ongkir untuk Ekspedisi Lokal Toko.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final parsedOjek = _parseRows(_ojekRows, 'Ojek Lokal');
    if (parsedOjek.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parsedOjek.error!), backgroundColor: Colors.red),
      );
      return;
    }

    final parsedEkspedisi = _parseRows(_ekspedisiRows, 'Ekspedisi Lokal');
    if (parsedEkspedisi.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(parsedEkspedisi.error!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final storeService = ref.read(storeServiceProvider);
      final updated = await storeService.updateLocalShippingSettings(
        storeId: store.id,
        localOjekEnabled: _ojekEnabled,
        localOjekRates: parsedOjek.tiers!,
        localEkspedisiEnabled: _ekspedisiEnabled,
        localEkspedisiRates: parsedEkspedisi.tiers!,
      );

      ref.invalidate(myStoreProvider);
      ref.invalidate(managedStoreProvider);
      ref.invalidate(publicStoreProvider(store.id));

      if (!mounted) return;
      setState(() => _store = updated);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Pengaturan ongkir lokal UMKM berhasil disimpan!',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan pengaturan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showAssignCourierDialog() async {
    final store = _store;
    if (store == null) return;

    final emailCtrl = TextEditingController();
    String selectedType = 'ojek';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Daftarkan Akun Kurir Toko'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan email akun kurir yang telah ditetapkan role-nya (ojek / ekspedisi) oleh Admin:',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Jenis Armada Kurir',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ojek',
                    child: Text('Driver Ojek Lokal Toko'),
                  ),
                  DropdownMenuItem(
                    value: 'ekspedisi',
                    child: Text('Kurir Ekspedisi Lokal Toko'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedType = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Login Kurir *',
                  hintText: 'kurir@contoh.com',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Tambahkan'),
            ),
          ],
        ),
      ),
    );

    final email = emailCtrl.text.trim();
    Future<void>.delayed(const Duration(milliseconds: 350), emailCtrl.dispose);

    if (confirmed != true || email.isEmpty) return;

    try {
      final service = ref.read(storeServiceProvider);
      await service.assignStoreCourierByEmail(
        storeId: store.id,
        email: email,
        courierType: selectedType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kurir $email berhasil ditugaskan ke toko ini.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menugaskan kurir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeCourier(Map<String, dynamic> courier) async {
    final id = courier['id']?.toString();
    if (id == null) return;

    try {
      await ref.read(storeServiceProvider).removeStoreCourier(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akses kurir toko berhasil dicabut.')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus kurir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengiriman Lokal Toko UMKM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : store == null
          ? Center(child: Text(_errorMessage ?? 'Toko tidak ditemukan'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGpsReadinessBanner(store),
                const SizedBox(height: 16),
                _buildServiceCard(
                  title: 'Ojek Lokal Toko (Pengantaran Instan)',
                  subtitle:
                      'Opsional. Aktifkan jika UMKM menyediakan pengantaran ojek instan mandiri berdasarkan rentang jarak (km).',
                  icon: Icons.two_wheeler_rounded,
                  accentColor: Colors.deepOrange.shade700,
                  enabled: _ojekEnabled,
                  onToggle: (val) {
                    setState(() {
                      _ojekEnabled = val;
                      if (val && _ojekRows.isEmpty) {
                        _addTierRow(_ojekRows, defaultPrice: 10000);
                      }
                    });
                  },
                  rows: _ojekRows,
                  defaultNewPrice: 10000,
                ),
                const SizedBox(height: 16),
                _buildServiceCard(
                  title: 'Ekspedisi Lokal / Armada Toko',
                  subtitle:
                      'Opsional. Aktifkan jika UMKM menyediakan pengiriman kurir/armada terjadwal milik toko.',
                  icon: Icons.local_shipping_outlined,
                  accentColor: AppColors.primaryHover,
                  enabled: _ekspedisiEnabled,
                  onToggle: (val) {
                    setState(() {
                      _ekspedisiEnabled = val;
                      if (val && _ekspedisiRows.isEmpty) {
                        _addTierRow(_ekspedisiRows, defaultPrice: 12000);
                      }
                    });
                  },
                  rows: _ekspedisiRows,
                  defaultNewPrice: 12000,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text(
                      'Simpan Tarif Pengiriman Lokal',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildStoreCouriersSection(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildGpsReadinessBanner(StoreModel store) {
    final ready = store.hasValidCoordinates;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ready ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready ? Colors.green.shade200 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ready ? Icons.gps_fixed_rounded : Icons.warning_amber_rounded,
            color: ready ? Colors.green.shade700 : Colors.orange.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready
                      ? 'Titik GPS Toko Aktif (${store.latitude!.toStringAsFixed(5)}, ${store.longitude!.toStringAsFixed(5)})'
                      : 'Titik GPS Toko Belum Diatur',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: ready
                        ? Colors.green.shade900
                        : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? 'Jarak pengiriman lokal dihitung otomatis di server dari titik GPS toko ke titik GPS alamat pembeli.'
                      : 'Wajib mengatur pinpoint lokasi GPS toko sebelum mengaktifkan Ojek/Ekspedisi Lokal.',
                  style: TextStyle(
                    fontSize: 12,
                    color: ready
                        ? Colors.green.shade800
                        : Colors.orange.shade900,
                  ),
                ),
                if (!ready) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await context.push('/seller/edit-store', extra: store);
                      await _loadData();
                    },
                    icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                    label: const Text('Atur Lokasi GPS Toko'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required List<_EditableTierRow> rows,
    required int defaultNewPrice,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? accentColor.withValues(alpha: 0.4) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accentColor.withValues(alpha: 0.12),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onToggle),
            ],
          ),
          if (enabled) ...[
            const Divider(height: 24),
            const Text(
              'Daftar Range Jarak (Km) & Ongkos Kirim (Rp)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Alamat pembeli di luar batas jarak tertinggi otomatis tidak dapat memilih layanan ini.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            ...List.generate(rows.length, (idx) {
              final row = rows[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.minCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Min (km)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.maxCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Maks (km)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: row.priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ongkir (Rp)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      tooltip: 'Hapus Baris',
                      onPressed: () => _removeTierRow(rows, idx),
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _addTierRow(rows, defaultPrice: defaultNewPrice),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tambah Range Jarak'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              rows.isEmpty
                  ? 'Nonaktif (pembeli hanya melihat kurir eksternal Biteship).'
                  : 'Nonaktif (${rows.length} range tersimpan: mulai ${CurrencyFormatter.format(int.tryParse(rows.first.priceCtrl.text) ?? 0)}).',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStoreCouriersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Akun Kurir / Driver Toko',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hanya kurir yang terdaftar di sini yang dapat melihat & mengklaim pesanan lokal lunas toko Anda.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showAssignCourierDialog,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                label: const Text('Tambah'),
              ),
            ],
          ),
          const Divider(height: 20),
          if (_storeCouriers.isEmpty)
            Text(
              'Belum ada akun kurir lokal yang ditugaskan ke toko ini.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            ..._storeCouriers.map((c) {
              final cType = c['courier_type']?.toString() ?? 'ojek';
              final isOjek = cType == 'ojek';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isOjek
                      ? Colors.deepOrange.shade50
                      : Colors.indigo.shade50,
                  child: Icon(
                    isOjek ? Icons.two_wheeler : Icons.local_shipping_outlined,
                    color: isOjek
                        ? Colors.deepOrange.shade700
                        : Colors.indigo.shade700,
                    size: 20,
                  ),
                ),
                title: Text(
                  c['full_name']?.toString() ?? 'Kurir Toko',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${c['email'] ?? '-'} • ${isOjek ? 'Ojek Lokal' : 'Ekspedisi Lokal'}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => _removeCourier(c),
                ),
              );
            }),
        ],
      ),
    );
  }
}
