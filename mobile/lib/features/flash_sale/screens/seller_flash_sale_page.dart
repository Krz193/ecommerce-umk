import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/flash_sale/models/sale_event_model.dart';
import 'package:mobile/features/flash_sale/providers/flash_sale_provider.dart';
import 'package:mobile/features/product/models/product_model.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerFlashSalePage extends ConsumerStatefulWidget {
  final String? storeId;

  const SellerFlashSalePage({super.key, this.storeId});

  @override
  ConsumerState<SellerFlashSalePage> createState() =>
      _SellerFlashSalePageState();
}

class _SellerFlashSalePageState extends ConsumerState<SellerFlashSalePage> {
  List<ProductModel> _storeProducts = [];
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadStoreProducts();
  }

  Future<String?> _resolveStoreId() async {
    if (widget.storeId != null && widget.storeId!.isNotEmpty) {
      return widget.storeId;
    }
    final store = await ref.read(managedStoreProvider.future);
    return store?.id;
  }

  Future<void> _loadStoreProducts() async {
    final storeId = await _resolveStoreId();
    if (storeId == null) {
      if (mounted) setState(() => _loadingProducts = false);
      return;
    }

    try {
      final res = await supabase
          .from('products')
          .select('id, name, price, stock, status, store_id, thumbnail_url')
          .eq('store_id', storeId)
          .isFilter('archived_at', null)
          .order('name');

      if (mounted) {
        setState(() {
          _storeProducts = (res as List)
              .whereType<Map<String, dynamic>>()
              .map(ProductModel.fromJson)
              .toList();
          _loadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  void _refresh(String storeId) {
    ref.invalidate(sellerSaleEventsProvider(storeId));
    ref.invalidate(publicSaleEventsProvider);
    _loadStoreProducts();
  }

  Future<void> _showCreateEventDialog(String storeId) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var startTime = DateTime.now();
    var endTime = DateTime.now().add(const Duration(days: 2));

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Buat Flash Sale Toko'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Judul Flash Sale *',
                    hintText: 'Contoh: Flash Sale Akhir Pekan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi Promo (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Waktu Mulai', style: TextStyle(fontSize: 13)),
                  subtitle: Text(DateFormatter.format(startTime)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final picked = await _pickDateTime(ctx, startTime);
                    if (picked != null) {
                      setModalState(() => startTime = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Waktu Berakhir', style: TextStyle(fontSize: 13)),
                  subtitle: Text(DateFormatter.format(endTime)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final picked = await _pickDateTime(ctx, endTime);
                    if (picked != null) {
                      setModalState(() => endTime = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty || !endTime.isAfter(startTime)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Judul wajib diisi dan waktu berakhir harus setelah waktu mulai',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogCtx);
                try {
                  await ref
                      .read(flashSaleServiceProvider)
                      .createStoreSaleEvent(
                        storeId: storeId,
                        title: title,
                        description: descCtrl.text,
                        startTime: startTime,
                        endTime: endTime,
                      );
                  _refresh(storeId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Flash Sale toko berhasil dibuat')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal membuat event: $e')),
                    );
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(BuildContext ctx, DateTime initial) async {
    final date = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !ctx.mounted) return null;
    final time = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return DateTime(date.year, date.month, date.day, initial.hour, initial.minute);
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _showAddItemDialog(SaleEventModel event, String storeId) async {
    if (_storeProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada produk toko yang tersedia')),
      );
      return;
    }

    var selectedProduct = _storeProducts.first;
    var discountType = 'percentage';
    final valueCtrl = TextEditingController(text: '20');
    final quotaCtrl = TextEditingController();
    final maxUserCtrl = TextEditingController(text: '2');

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text('Daftarkan Produk ke ${event.title}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedProduct.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Produk Toko',
                    border: OutlineInputBorder(),
                  ),
                  items: _storeProducts.map((p) {
                    return DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.name} (${CurrencyFormatter.format(p.price)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    final found = _storeProducts.where((p) => p.id == id).firstOrNull;
                    if (found != null) {
                      setModalState(() => selectedProduct = found);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: discountType,
                  decoration: const InputDecoration(
                    labelText: 'Tipe Diskon',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Persentase (%)')),
                    DropdownMenuItem(value: 'nominal', child: Text('Potongan Nominal (Rp)')),
                    DropdownMenuItem(value: 'fixed_price', child: Text('Harga Khusus Sale (Rp)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => discountType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: discountType == 'percentage'
                        ? 'Persentase Diskon (%) *'
                        : discountType == 'nominal'
                            ? 'Nominal Potongan (Rp) *'
                            : 'Harga Flash Sale (Rp) *',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quotaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kuota Sale (Kosongkan = ikut stok)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxUserCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Maks Beli per Pembeli (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = double.tryParse(valueCtrl.text.trim());
                if (val == null || val <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nilai diskon tidak valid')),
                  );
                  return;
                }
                if (discountType == 'percentage' && val > 99) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Persentase maksimal 99%')),
                  );
                  return;
                }

                final quota = int.tryParse(quotaCtrl.text.trim());
                final maxUser = int.tryParse(maxUserCtrl.text.trim());
                Navigator.pop(dialogCtx);

                try {
                  await ref
                      .read(flashSaleServiceProvider)
                      .upsertSaleEventItem(
                        saleEventId: event.id,
                        productId: selectedProduct.id,
                        storeId: storeId,
                        discountType: discountType,
                        discountValue: val,
                        saleQuota: quota != null && quota > 0 ? quota : null,
                        maxQtyPerUser:
                            maxUser != null && maxUser > 0 ? maxUser : null,
                      );
                  _refresh(storeId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Produk ditambahkan ke Flash Sale')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menyimpan produk sale: $e')),
                    );
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(managedStoreProvider);
    final effectiveStoreId = widget.storeId ?? storeAsync.asData?.value?.id;

    if (effectiveStoreId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flash Sale Toko')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final eventsAsync = ref.watch(sellerSaleEventsProvider(effectiveStoreId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash Sale & Promo Event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(effectiveStoreId),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.bolt),
        label: const Text('Buat Flash Sale'),
        onPressed: () => _showCreateEventDialog(effectiveStoreId),
      ),
      body: _loadingProducts
          ? const Center(child: CircularProgressIndicator())
          : eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (events) {
                if (events.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada event Flash Sale.\nKlik tombol di bawah untuk membuat promo.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refresh(effectiveStoreId),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final isOwnedByStore = !event.isPlatformEvent;

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOwnedByStore
                                          ? Colors.orange.shade50
                                          : Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isOwnedByStore
                                          ? 'Event Toko Saya'
                                          : 'Event Platform Admin',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isOwnedByStore
                                            ? AppColors.primaryHover
                                            : Colors.indigo.shade700,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isOwnedByStore)
                                    Switch(
                                      value: event.isActive,
                                      onChanged: (val) async {
                                        await ref
                                            .read(flashSaleServiceProvider)
                                            .toggleStoreSaleEvent(
                                              eventId: event.id,
                                              storeId: effectiveStoreId,
                                              isActive: val,
                                            );
                                        _refresh(effectiveStoreId);
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                event.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormatter.format(event.startTime)} — ${DateFormatter.format(event.endTime)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const Divider(height: 20),
                              if (event.items.isEmpty)
                                Text(
                                  'Belum ada produk toko Anda yang terdaftar di event ini.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                )
                              else
                                ...event.items.map(
                                  (item) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(
                                      item.product?.name ?? 'Produk',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Harga Sale: ${CurrencyFormatter.format(item.salePrice)} · Terjual: ${item.soldCount}${item.saleQuota != null ? '/${item.saleQuota}' : ''}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        await ref
                                            .read(flashSaleServiceProvider)
                                            .deleteSaleEventItem(
                                              itemId: item.id,
                                              storeId: effectiveStoreId,
                                            );
                                        _refresh(effectiveStoreId);
                                      },
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _showAddItemDialog(
                                      event,
                                      effectiveStoreId,
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Tambah / Ubah Produk'),
                                  ),
                                  if (isOwnedByStore)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_forever_outlined,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        await ref
                                            .read(flashSaleServiceProvider)
                                            .deleteStoreSaleEvent(
                                              eventId: event.id,
                                              storeId: effectiveStoreId,
                                            );
                                        _refresh(effectiveStoreId);
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
