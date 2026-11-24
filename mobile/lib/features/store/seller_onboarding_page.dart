import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/widgets/map_point_picker_field.dart';
import 'package:mobile/features/address/providers/address_provider.dart';
import 'package:mobile/features/address/widgets/biteship_area_picker_sheet.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerOnboardingPage extends ConsumerStatefulWidget {
  const SellerOnboardingPage({super.key});

  @override
  ConsumerState<SellerOnboardingPage> createState() =>
      _SellerOnboardingPageState();
}

class _SellerOnboardingPageState extends ConsumerState<SellerOnboardingPage> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final provinceController = TextEditingController();
  final cityController = TextEditingController();
  final districtController = TextEditingController();
  final postalCodeController = TextEditingController();
  final notesController = TextEditingController();

  String? selectedBiteshipAreaId;
  double? selectedLatitude;
  double? selectedLongitude;

  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    nameController.addListener(clearError);
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

  String makeSlug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String readableError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    setState(() {
      errorMessage = null;
    });
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

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final appUser = await ref.read(appUserProvider.future);

      if (appUser == null) {
        throw Exception('User profile not found');
      }

      if (appUser.isBuyer) {
        await authService.becomeSeller();
      }

      final storeService = ref.read(storeServiceProvider);
      final slug = makeSlug(nameController.text);

      if (slug.isEmpty) {
        throw Exception('Store name must contain letters or numbers');
      }

      await storeService.createStore(
        name: nameController.text.trim(),
        slug: slug,
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

      ref.invalidate(appUserProvider);
      ref.invalidate(myStoreProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Toko berhasil dibuat')));

      context.go('/home');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = readableError(error);

      setState(() {
        errorMessage = message;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingStore = ref.watch(myStoreProvider);
    final hasAreaSelected =
        cityController.text.isNotEmpty || provinceController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Buka Toko UMK')),

      body: existingStore.when(
        data: (store) {
          if (store != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go('/seller/store');
              }
            });

            return const Center(child: CircularProgressIndicator());
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: Form(
                key: formKey,

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Toko UMK *',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama toko wajib diisi';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Telepon / WhatsApp Toko',
                      ),
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 16),

                    InkWell(
                      onTap: pickBiteshipArea,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasAreaSelected
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : Colors.grey.shade300,
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
                                    'Area Asal Pengiriman (Kota/Kecamatan)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    hasAreaSelected
                                        ? '${districtController.text.isNotEmpty ? '${districtController.text}, ' : ''}${cityController.text}, ${provinceController.text} ${postalCodeController.text}'
                                        : 'Pilih Kota / Kecamatan',
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
                      decoration: const InputDecoration(labelText: 'Kode Pos'),
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Alamat Lengkap Toko',
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Patokan Lokasi Toko (Opsional)',
                        hintText: 'Cth: Sebelah masjid / pagar hijau',
                      ),
                      minLines: 1,
                      maxLines: 2,
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
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi Toko',
                      ),
                      minLines: 3,
                      maxLines: 5,
                    ),

                    const SizedBox(height: 24),

                    if (errorMessage != null) ...[
                      Text(
                        errorMessage!,

                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],

                    ElevatedButton(
                      onPressed: isLoading ? null : submit,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(),
                            )
                          : const Text('Buka Toko'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        error: (error, stackTrace) {
          return Center(child: Text(error.toString()));
        },
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
