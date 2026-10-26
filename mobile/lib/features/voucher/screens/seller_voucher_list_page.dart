import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/product/models/product_model.dart';
import 'package:mobile/features/store/providers/store_provider.dart';
import 'package:mobile/features/voucher/models/store_voucher_model.dart';
import 'package:mobile/features/voucher/services/voucher_service.dart';

class SellerVoucherListPage extends ConsumerStatefulWidget {
  final String? storeId;

  const SellerVoucherListPage({super.key, this.storeId});

  @override
  ConsumerState<SellerVoucherListPage> createState() =>
      _SellerVoucherListPageState();
}

class _SellerVoucherListPageState extends ConsumerState<SellerVoucherListPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<StoreVoucherModel> _vouchers = [];
  List<ProductModel> _storeProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchVouchersAndProducts();
  }

  String? _getEffectiveStoreId() {
    if (widget.storeId != null && widget.storeId!.isNotEmpty) {
      return widget.storeId;
    }
    final store = ref.read(myStoreProvider).asData?.value;
    return store?.id;
  }

  Future<void> _fetchVouchersAndProducts() async {
    final storeId = _getEffectiveStoreId();
    if (storeId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Toko belum ditemukan';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(voucherServiceProvider);
      final list = await service.getStoreVouchers(storeId);

      // Fetch store products for multi-select selector
      final prodsRes = await supabase
          .from('products')
          .select('id, name, price, stock, status, store_id')
          .eq('store_id', storeId)
          .inFilter('status', ['published', 'active']);

      final prods = (prodsRes as List)
          .map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _vouchers = list;
          _storeProducts = prods;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showCreateVoucherDialog() {
    final storeId = _getEffectiveStoreId();
    if (storeId == null) return;

    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final minPurchaseCtrl = TextEditingController(text: '0');

    String selectedScope = 'order'; // 'order' vs 'product'
    List<String> selectedProductIds = [];
    String selectedType = 'nominal'; // 'nominal', 'percentage', 'fixed_price'
    bool isSingleUse = true;
    bool hasExpiry = true;
    DateTime expiryDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: const Text('Buat Voucher & Harga Khusus'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. DROPDOWN PALING ATAS: LINGKUP VOUCHER
                      const Text(
                        'Lingkup Voucher *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedScope,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'order',
                            child: Text('Per Order (Seluruh Belanja Toko)'),
                          ),
                          DropdownMenuItem(
                            value: 'product',
                            child: Text('Per Produk Spesifik (Pilihan)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedScope = val;
                              // Jika order, batasi tipe fixed_price agar tidak borongan berbahaya
                              if (selectedScope == 'order' && selectedType == 'fixed_price') {
                                selectedType = 'nominal';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedScope == 'order'
                            ? 'Voucher berlaku untuk total subtotal belanja toko (semua item).'
                            : 'Voucher HANYA memotong produk-produk tertentu yang Anda pilih.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 14),

                      // 1.5 SELECTOR MULTIPLE PRODUK SPESIFIK (JIKA SCOPE == 'product')
                      if (selectedScope == 'product') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pilih Produk yang Berlaku *',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${selectedProductIds.length} dipilih',
                              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_storeProducts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Toko belum memiliki produk aktif. Tambah produk terlebih dahulu.',
                              style: TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          )
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 160),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _storeProducts.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (c, idx) {
                                final p = _storeProducts[idx];
                                final isChecked = selectedProductIds.contains(p.id);
                                return CheckboxListTile(
                                  dense: true,
                                  value: isChecked,
                                  title: Text(p.name, style: const TextStyle(fontSize: 13)),
                                  subtitle: Text(
                                    CurrencyFormatter.format(p.price),
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selectedProductIds.add(p.id);
                                      } else {
                                        selectedProductIds.remove(p.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Jika buyer membeli beberapa barang di keranjang, hanya produk yang dicentang yang dipotong. Barang lain tetap harga normal.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 2. KODE VOUCHER
                      TextField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Kode Voucher *',
                          hintText: 'Contoh: TEMAN-BUDI',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kode voucher yang dimasukkan oleh pembeli saat checkout.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),

                      // 3. CATATAN / JUDUL
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Catatan / Keterangan *',
                          hintText: 'Contoh: Diskon Pelanggan Baru / Promo Spesial',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keterangan voucher untuk catatan pembukuan toko Anda.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),

                      // 4. TIPE POTONGAN
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Tipe Potongan *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'nominal',
                            child: Text('Potongan Nominal (Rp)'),
                          ),
                          const DropdownMenuItem(
                            value: 'percentage',
                            child: Text('Potongan Persen (%)'),
                          ),
                          if (selectedScope == 'product')
                            const DropdownMenuItem(
                              value: 'fixed_price',
                              child: Text('Harga Khusus Baru (Set Harga Baru)'),
                            ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedType == 'nominal'
                            ? 'Memotong nominal rupiah langsung dari harga produk atau order.'
                            : selectedType == 'percentage'
                                ? 'Memotong persentase diskon dari harga.'
                                : 'Mengubah harga produk target langsung menjadi harga baru yang ditentukan.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),

                      // 5. NILAI POTONGAN
                      TextField(
                        controller: valueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: selectedType == 'nominal'
                              ? 'Nominal Potongan (Rp) *'
                              : selectedType == 'percentage'
                                  ? 'Persentase Diskon (%) *'
                                  : 'Target Harga Baru Per Produk (Rp) *',
                          hintText: selectedType == 'percentage' ? '15' : '50000',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(
                            selectedType == 'percentage'
                                ? Icons.percent
                                : Icons.monetization_on_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedType == 'fixed_price'
                            ? 'Misal harga asli produk Rp 200.000, Anda set Rp 120.000, maka pembeli bayar Rp 120.000.'
                            : 'Masukkan angka tanpa titik atau tanda persen.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),

                      // 6. MINIMAL BELANJA
                      TextField(
                        controller: minPurchaseCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Minimal Belanja (Rp)',
                          hintText: '0 (tanpa syarat)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Isi 0 jika tidak ada syarat minimal total belanja toko.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),

                      // 7. SWITCH SEKALI PAKAI
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sekali Pakai Saja (1x)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Voucher langsung tidak berlaku setelah digunakan satu kali.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        value: isSingleUse,
                        onChanged: (val) {
                          setModalState(() => isSingleUse = val);
                        },
                      ),

                      // 8. SWITCH BATAS TANGGAL
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Batasi Waktu Berlaku', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          hasExpiry
                              ? 'Kedaluwarsa pada: ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}'
                              : 'Voucher berlaku selamanya tanpa batas waktu kadaluwarsa.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        value: hasExpiry,
                        onChanged: (val) {
                          setModalState(() => hasExpiry = val);
                        },
                      ),
                      if (hasExpiry)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Atur Tanggal Kedaluwarsa', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: expiryDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  expiryDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    23,
                                    59,
                                    59,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final code = codeCtrl.text.trim().toUpperCase();
                    final title = titleCtrl.text.trim();
                    final val = double.tryParse(valueCtrl.text.trim());
                    final minP = double.tryParse(minPurchaseCtrl.text.trim()) ?? 0;

                    if (code.isEmpty || title.isEmpty || val == null || val <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lengkapi kode, catatan, dan nilai diskon')),
                      );
                      return;
                    }

                    if (selectedScope == 'product' && selectedProductIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pilih minimal 1 produk spesifik untuk voucher per produk')),
                      );
                      return;
                    }

                    final newVoucher = StoreVoucherModel(
                      id: '',
                      storeId: storeId,
                      code: code,
                      title: title,
                      scope: selectedScope,
                      applicableProductIds: selectedScope == 'product' ? selectedProductIds : [],
                      discountType: selectedType,
                      discountValue: val,
                      minPurchase: minP,
                      usageLimit: isSingleUse ? 1 : null,
                      endDate: hasExpiry ? expiryDate : null,
                      isActive: true,
                    );

                    Navigator.pop(dialogCtx);
                    try {
                      final service = ref.read(voucherServiceProvider);
                      await service.createVoucher(newVoucher);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Voucher $code berhasil dibuat! Berikan ke pembeli kenalan.'),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                      _fetchVouchersAndProducts();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal membuat voucher: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Simpan Voucher'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleVoucher(StoreVoucherModel voucher) async {
    try {
      final service = ref.read(voucherServiceProvider);
      await service.toggleVoucherStatus(voucher.id, !voucher.isActive);
      _fetchVouchersAndProducts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah status: $e')),
      );
    }
  }

  Future<void> _deleteVoucher(StoreVoucherModel voucher) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Voucher ${voucher.code}?'),
        content: const Text('Voucher yang dihapus tidak dapat digunakan kembali oleh pembeli.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final service = ref.read(voucherServiceProvider);
        await service.deleteVoucher(voucher.id);
        _fetchVouchersAndProducts();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voucher Toko & Harga Khusus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchVouchersAndProducts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Buat Voucher'),
        onPressed: _showCreateVoucherDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchVouchersAndProducts,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_person_outlined, color: Colors.teal.shade800),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Voucher Toko & Promo Khusus',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Atur voucher per order (seluruh belanja) atau per produk spesifik (pilih satu/beberapa barang). Jika buyer belanja banyak barang, hanya produk target yang terpotong.',
                                style: TextStyle(fontSize: 12, color: Colors.teal.shade800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (_vouchers.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: [
                            Icon(Icons.confirmation_number_outlined,
                                size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'Belum ada voucher toko yang dibuat.\nKlik tombol di bawah untuk membuat voucher pertama.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._vouchers.map((v) => _buildVoucherCard(v)),
                  const SizedBox(height: 70), // Spacing for FAB
                ],
              ),
            ),
    );
  }

  Widget _buildVoucherCard(StoreVoucherModel voucher) {
    String valueDisplay = '';
    if (voucher.discountType == 'nominal') {
      valueDisplay = 'Potongan ${CurrencyFormatter.format(voucher.discountValue.round())}';
    } else if (voucher.discountType == 'percentage') {
      valueDisplay = 'Diskon ${voucher.discountValue.toStringAsFixed(0)}%';
    } else {
      valueDisplay = 'Harga Khusus ${CurrencyFormatter.format(voucher.discountValue.round())}';
    }

    final isExpired = voucher.isExpired;
    final isExhausted = voucher.isQuotaExhausted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Text(
                        voucher.code,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: voucher.isProductSpecific ? Colors.purple.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        voucher.isProductSpecific
                            ? '${voucher.applicableProductIds.length} Produk Pilihan'
                            : 'Per Order',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: voucher.isProductSpecific ? Colors.purple.shade800 : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: voucher.isActive,
                  onChanged: (val) => _toggleVoucher(voucher),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              voucher.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              valueDisplay,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.green.shade800,
                fontSize: 14,
              ),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.repeat, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  voucher.isSingleUse
                      ? 'Sekali Pakai (Terpakai: ${voucher.usedCount}/1)'
                      : 'Kuota: ${voucher.usedCount}/${voucher.usageLimit ?? "Tak terbatas"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const Spacer(),
                if (isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Kedaluwarsa',
                        style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else if (isExhausted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Kuota Habis',
                        style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else if (voucher.endDate != null)
                  Text(
                    'Exp: ${voucher.endDate!.day}/${voucher.endDate!.month}/${voucher.endDate!.year}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteVoucher(voucher),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
