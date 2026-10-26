import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';

import 'package:mobile/features/address/models/address_model.dart';
import 'package:mobile/features/address/providers/address_provider.dart';
import 'package:mobile/features/address/widgets/biteship_area_picker_sheet.dart';

class AddressFormPage extends ConsumerStatefulWidget {
  final String? addressId;

  const AddressFormPage({super.key, this.addressId});

  @override
  ConsumerState<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends ConsumerState<AddressFormPage> {
  final formKey = GlobalKey<FormState>();

  final labelController = TextEditingController();
  final recipientController = TextEditingController();
  final phoneController = TextEditingController();
  final provinceController = TextEditingController();
  final cityController = TextEditingController();
  final districtController = TextEditingController();
  final postalCodeController = TextEditingController();
  final fullAddressController = TextEditingController();
  final notesController = TextEditingController();

  String? selectedBiteshipAreaId;
  bool initialized = false;
  bool isSaving = false;
  bool isDefault = false;

  bool get isEditing => widget.addressId != null;

  @override
  void dispose() {
    labelController.dispose();
    recipientController.dispose();
    phoneController.dispose();
    provinceController.dispose();
    cityController.dispose();
    districtController.dispose();
    postalCodeController.dispose();
    fullAddressController.dispose();
    notesController.dispose();

    super.dispose();
  }

  void initialize(AddressModel? address) {
    if (initialized || address == null) {
      return;
    }

    initialized = true;
    labelController.text = address.label ?? '';
    recipientController.text = address.recipientName;
    phoneController.text = address.phoneNumber;
    provinceController.text = address.province;
    cityController.text = address.city;
    districtController.text = address.district ?? '';
    postalCodeController.text = address.postalCode ?? '';
    fullAddressController.text = address.fullAddress;
    notesController.text = address.notes ?? '';
    selectedBiteshipAreaId = address.biteshipAreaId;
    isDefault = address.isDefault;
  }

  AddressModel? findAddress(List<AddressModel> addresses) {
    for (final address in addresses) {
      if (address.id == widget.addressId) {
        return address;
      }
    }

    return null;
  }

  Future<void> pickBiteshipArea() async {
    final service = ref.read(addressServiceProvider);
    final initialQuery = districtController.text.isNotEmpty
        ? districtController.text
        : (cityController.text.isNotEmpty ? cityController.text : null);

    final selected = await BiteshipAreaPickerSheet.show(
      context,
      addressService: service,
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
    }
  }

  Future<void> saveAddress() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (provinceController.text.trim().isEmpty || cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih kota / kecamatan terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final service = ref.read(addressServiceProvider);

      if (isEditing) {
        await service.updateAddress(
          addressId: widget.addressId!,
          label: labelController.text,
          recipientName: recipientController.text.trim(),
          phoneNumber: phoneController.text.trim(),
          province: provinceController.text.trim(),
          city: cityController.text.trim(),
          district: districtController.text,
          postalCode: postalCodeController.text,
          fullAddress: fullAddressController.text.trim(),
          notes: notesController.text.trim(),
          biteshipAreaId: selectedBiteshipAreaId,
          isDefault: isDefault,
        );
      } else {
        await service.createAddress(
          label: labelController.text,
          recipientName: recipientController.text.trim(),
          phoneNumber: phoneController.text.trim(),
          province: provinceController.text.trim(),
          city: cityController.text.trim(),
          district: districtController.text,
          postalCode: postalCodeController.text,
          fullAddress: fullAddressController.text.trim(),
          notes: notesController.text.trim(),
          biteshipAreaId: selectedBiteshipAreaId,
          isDefault: isDefault,
        );
      }

      ref.invalidate(addressProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Alamat berhasil diperbarui' : 'Alamat berhasil ditambahkan'),
        ),
      );

      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressAsync = ref.watch(addressProvider);

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Alamat' : 'Tambah Alamat')),
      body: addressAsync.when(
        data: (addresses) {
          final address = isEditing ? findAddress(addresses) : null;

          if (isEditing && address == null) {
            return const Center(child: Text('Alamat tidak ditemukan'));
          }

          initialize(address);

          return buildForm();
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

  Widget buildForm() {
    final hasAreaSelected = cityController.text.isNotEmpty || provinceController.text.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildTextField(labelController, 'Label Alamat (Rumah, Kantor)', requiredField: false),
              const SizedBox(height: 16),
              buildTextField(recipientController, 'Nama Penerima'),
              const SizedBox(height: 16),
              buildTextField(
                phoneController,
                'Nomor Telepon',
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),

              // Area Selector
              InkWell(
                onTap: pickBiteshipArea,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasAreaSelected
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : Colors.grey.shade300,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.location_city_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kota, Kecamatan, Kode Pos',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (hasAreaSelected)
                              Text(
                                '${districtController.text.isNotEmpty ? '${districtController.text}, ' : ''}${cityController.text}, ${provinceController.text} ${postalCodeController.text}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            else
                              Text(
                                'Pilih Kota atau Kecamatan',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: fullAddressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat Lengkap',
                  hintText: 'Nama Jalan, No. Rumah, RT/RW, Patokan gang',
                ),
                minLines: 3,
                maxLines: 5,
                validator: requiredValidator('Alamat lengkap wajib diisi'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Detail Tambahan / Patokan (Opsional)',
                  hintText: 'Cth: Blok B3 No. 5, rumah pagar hitam, seberang masjid',
                ),
                minLines: 1,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: isDefault,
                onChanged: (value) {
                  setState(() {
                    isDefault = value ?? false;
                  });
                },
                title: const Text('Jadikan sebagai alamat utama'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isSaving ? null : saveAddress,
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Simpan Alamat' : 'Tambah Alamat'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField buildTextField(
    TextEditingController controller,
    String label, {
    bool requiredField = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: requiredField ? requiredValidator('$label wajib diisi') : null,
    );
  }

  String? Function(String?) requiredValidator(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }

      return null;
    };
  }
}
