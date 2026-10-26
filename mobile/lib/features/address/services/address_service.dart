import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/address/models/address_model.dart';
import 'package:mobile/features/address/models/biteship_area_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddressException implements Exception {
  final String message;

  AddressException(this.message);

  @override
  String toString() => message;
}

class AddressService {
  final SupabaseClient _supabase = supabase;

  Future<List<AddressModel>> getAddresses() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    final response = await _supabase
        .from('addresses')
        .select('''
          id,
          label,
          recipient_name,
          recipient_phone,
          province,
          city,
          district,
          postal_code,
          full_address,
          notes,
          biteship_area_id,
          is_default
        ''')
        .eq('user_id', user.id)
        .order('is_default', ascending: false)
        .order('updated_at', ascending: false);

    return response
        .map<AddressModel>((item) => AddressModel.fromMap(item))
        .toList();
  }

  Future<AddressModel> createAddress({
    required String recipientName,
    required String phoneNumber,
    required String province,
    required String city,
    required String fullAddress,
    String? label,
    String? district,
    String? postalCode,
    String? notes,
    String? biteshipAreaId,
    bool isDefault = false,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw AddressException('User not logged in');
    }

    final addresses = await getAddresses();
    final shouldBeDefault = isDefault || addresses.isEmpty;

    if (shouldBeDefault) {
      await clearDefaultAddress(user.id);
    }

    try {
      final response = await _supabase
          .from('addresses')
          .insert({
            'user_id': user.id,
            'label': blankToNull(label),
            'recipient_name': recipientName,
            'recipient_phone': phoneNumber,
            'province': province,
            'city': city,
            'district': blankToNull(district),
            'postal_code': blankToNull(postalCode),
            'full_address': fullAddress,
            'notes': blankToNull(notes),
            'biteship_area_id': blankToNull(biteshipAreaId),
            'is_default': shouldBeDefault,
          })
          .select()
          .single();

      return AddressModel.fromMap(response);
    } on PostgrestException catch (error) {
      throw AddressException(error.message);
    }
  }

  Future<AddressModel> updateAddress({
    required String addressId,
    required String recipientName,
    required String phoneNumber,
    required String province,
    required String city,
    required String fullAddress,
    String? label,
    String? district,
    String? postalCode,
    String? notes,
    String? biteshipAreaId,
    bool isDefault = false,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw AddressException('User not logged in');
    }

    if (isDefault) {
      await clearDefaultAddress(user.id);
    }

    try {
      final response = await _supabase
          .from('addresses')
          .update({
            'label': blankToNull(label),
            'recipient_name': recipientName,
            'recipient_phone': phoneNumber,
            'province': province,
            'city': city,
            'district': blankToNull(district),
            'postal_code': blankToNull(postalCode),
            'full_address': fullAddress,
            'notes': blankToNull(notes),
            'biteship_area_id': blankToNull(biteshipAreaId),
            'is_default': isDefault,
          })
          .eq('id', addressId)
          .eq('user_id', user.id)
          .select()
          .single();

      return AddressModel.fromMap(response);
    } on PostgrestException catch (error) {
      throw AddressException(error.message);
    }
  }

  Future<void> deleteAddress(String addressId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw AddressException('User not logged in');
    }

    final addresses = await getAddresses();
    AddressModel? deletedAddress;

    for (final address in addresses) {
      if (address.id == addressId) {
        deletedAddress = address;
        break;
      }
    }

    try {
      await _supabase
          .from('addresses')
          .delete()
          .eq('id', addressId)
          .eq('user_id', user.id);

      if (deletedAddress?.isDefault == true) {
        final remaining = await getAddresses();

        if (remaining.isNotEmpty) {
          await setDefaultAddress(remaining.first.id);
        }
      }
    } on PostgrestException catch (error) {
      throw AddressException(error.message);
    }
  }

  Future<void> setDefaultAddress(String addressId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw AddressException('User not logged in');
    }

    await clearDefaultAddress(user.id);

    try {
      await _supabase
          .from('addresses')
          .update({'is_default': true})
          .eq('id', addressId)
          .eq('user_id', user.id);
    } on PostgrestException catch (error) {
      throw AddressException(error.message);
    }
  }

  Future<void> clearDefaultAddress(String userId) async {
    await _supabase
        .from('addresses')
        .update({'is_default': false})
        .eq('user_id', userId)
        .eq('is_default', true);
  }

  Future<List<BiteshipAreaModel>> searchBiteshipAreas(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      return [];
    }

    try {
      final response = await _supabase.functions.invoke(
        'biteship-areas',
        method: HttpMethod.get,
        queryParameters: {'input': trimmed},
      );

      final data = response.data;
      if (data is Map && data['success'] == true && data['areas'] is List) {
        return (data['areas'] as List)
            .map<BiteshipAreaModel>(
              (item) => BiteshipAreaModel.fromMap(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  String? blankToNull(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
