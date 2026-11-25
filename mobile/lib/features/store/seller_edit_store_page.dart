import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/widgets/map_point_picker_field.dart';
import 'package:mobile/features/address/providers/address_provider.dart';
import 'package:mobile/features/address/widgets/biteship_area_picker_sheet.dart';
import 'package:mobile/features/store/models/store_model.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerEditStorePage extends ConsumerStatefulWidget {
  final StoreModel store;

  const SellerEditStorePage({super.key, required this.store});

  @override
  ConsumerState<SellerEditStorePage> createState() =>
      _SellerEditStorePageState();
}

class _SellerEditStorePageState extends ConsumerState<SellerEditStorePage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  late final TextEditingController provinceController;
  late final TextEditingController cityController;
  late final TextEditingController districtController;
  late final TextEditingController postalCodeController;
  late final TextEditingController notesController;

  String? selectedBiteshipAreaId;
  double? selectedLatitude;
  double? selectedLongitude;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.store.name);
    descriptionController = TextEditingController(
      text: widget.store.description ?? '',
    );
    phoneController = TextEditingController(text: widget.store.phone ?? '');
    addressController = TextEditingController(text: widget.store.address ?? '');
    provinceController = TextEditingController(
      text: widget.store.province ?? '',
    );
    cityController = TextEditingController(text: widget.store.city ?? '');
    districtController = TextEditingController(
      text: widget.store.district ?? '',
    );
    postalCodeController = TextEditingController(
      text: widget.store.postalCode ?? '',
    );
    notesController = TextEditingController(text: widget.store.notes ?? '');
    selectedBiteshipAreaId = widget.store.biteshipAreaId;
    selectedLatitude = widget.store.latitude;
    selectedLongitude = widget.store.longitude;
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    phoneController.dispose();
    addressController.dispose();
    provinceController.dispose();
    cityController.dispose();
    districtController.dispose();
    postalCodeController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> pickBiteshipArea() async {
    final addressService = ref.read(addressServiceProvider);
    final initialQuery = districtController.text.isNotEmpty
        ? districtController.text
        : (cityController.text.isNotEmpty ? cityController.text : null);

    final selected = await BiteshipAreaPickerSheet.show(
      context,
      addressService: addressService,
      initialQuery: initialQuery,
    );

    if (selected != null) {
      setState(() {
        selectedBiteshipAreaId = selected.id;
        provinceController.text = selected.province;
        cityController.text = selected.city;
        districtController.text = selected.district;
        postalCodeController.text = selected.postalCode;
      });
      final geocoded = await MapPointPickerField.geocodeQuery(
        '${selected.district}, ${selected.city}, ${selected.province}',
      );
      if (geocoded != null && mounted) {
        setState(() {
          selectedLatitude = geocoded.latitude;
          selectedLongitude = geocoded.longitude;
        });
      }
    }
  }

  Future<void> saveStoreProfile() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final storeService = ref.read(storeServiceProvider);
      await storeService.updateStore(
        storeId: widget.store.id,
        name: nameController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        phone: phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
        address: addressController.text.trim().isEmpty
            ? null
            : addressController.text.trim(),
        province: provinceController.text.trim().isEmpty
            ? null
            : provinceController.text.trim(),
        city: cityController.text.trim().isEmpty
            ? null
            : cityController.text.trim(),
        district: districtController.text.trim().isEmpty
            ? null
            : districtController.text.trim(),
        postalCode: postalCodeController.text.trim().isEmpty
            ? null
            : postalCodeController.text.trim(),
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
        biteshipAreaId: selectedBiteshipAreaId,
        latitude: selectedLatitude,
        longitude: selectedLongitude,
      );

      ref.invalidate(myStoreProvider);
      ref.invalidate(managedStoreProvider);
      ref.invalidate(publicStoreProvider(widget.store.id));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil Toko UMK berhasil diperbarui!')),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui toko: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAreaSelected =
        cityController.text.isNotEmpty || provinceController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil & Lokasi Toko UMK')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Toko UMK *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Nama toko wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon / WhatsApp Toko',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: pickBiteshipArea,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasAreaSelected
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : Colors.grey.shade400,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_city_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Area Pengiriman Biteship (Kota/Kecamatan)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hasAreaSelected
                                  ? '${districtController.text.isNotEmpty ? '${districtController.text}, ' : ''}${cityController.text}, ${provinceController.text} ${postalCodeController.text}'
                                  : 'Pilih Kota / Kecamatan Asal Toko',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: hasAreaSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: hasAreaSelected
                                    ? AppColors.textPrimary
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: postalCodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kode Pos Toko',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Alamat Lengkap Toko UMK',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Patokan Lokasi Toko untuk Kurir (Opsional)',
                  hintText: 'Cth: Ruko No. 4 sebelah apotek, gerbang hijau',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.signpost_outlined),
                ),
              ),
              const SizedBox(height: 16),
              MapPointPickerField(
                latitude: selectedLatitude,
                longitude: selectedLongitude,
                initialQuery: [
                  addressController.text.trim(),
                  districtController.text.trim(),
                  cityController.text.trim(),
                ].where((e) => e.isNotEmpty).join(', '),
                label: 'Titik GPS Pickup Toko (Pinpoint Peta)',
                helperText:
                    'Menentukan lokasi penjemputan kurir Instant (Gojek/Grab/Ojek) & akurasi jarak ongkir.',
                onPointSelected: (point) {
                  setState(() {
                    selectedLatitude = point.latitude;
                    selectedLongitude = point.longitude;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi / Profil Singkat Toko UMK',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isSaving ? null : saveStoreProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primary,
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Simpan Perubahan Toko',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
