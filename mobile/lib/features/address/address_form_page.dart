import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/features/address/models/address_model.dart';
import 'package:mobile/features/address/providers/address_provider.dart';

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

  Future<void> saveAddress() async {
    if (!formKey.currentState!.validate()) {
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
          isDefault: isDefault,
        );
      }

      ref.invalidate(addressProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Address updated' : 'Address added'),
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
      appBar: AppBar(title: Text(isEditing ? 'Edit Address' : 'Add Address')),
      body: addressAsync.when(
        data: (addresses) {
          final address = isEditing ? findAddress(addresses) : null;

          if (isEditing && address == null) {
            return const Center(child: Text('Address not found'));
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildTextField(labelController, 'Label', requiredField: false),
              const SizedBox(height: 16),
              buildTextField(recipientController, 'Recipient Name'),
              const SizedBox(height: 16),
              buildTextField(
                phoneController,
                'Phone Number',
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              buildTextField(provinceController, 'Province'),
              const SizedBox(height: 16),
              buildTextField(cityController, 'City'),
              const SizedBox(height: 16),
              buildTextField(
                districtController,
                'District',
                requiredField: false,
              ),
              const SizedBox(height: 16),
              buildTextField(
                postalCodeController,
                'Postal Code',
                requiredField: false,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: fullAddressController,
                decoration: const InputDecoration(labelText: 'Full Address'),
                minLines: 3,
                maxLines: 5,
                validator: requiredValidator('Full address required'),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: isDefault,
                onChanged: (value) {
                  setState(() {
                    isDefault = value ?? false;
                  });
                },
                title: const Text('Set as default address'),
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
                    : Text(isEditing ? 'Save Address' : 'Add Address'),
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
      validator: requiredField ? requiredValidator('$label required') : null,
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
