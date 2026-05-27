import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/address/models/address_model.dart';
import 'package:mobile/features/address/services/address_service.dart';

final addressServiceProvider = Provider<AddressService>((ref) {
  return AddressService();
});

final addressProvider = FutureProvider<List<AddressModel>>((ref) async {
  final addressService = ref.read(addressServiceProvider);

  return addressService.getAddresses();
});
