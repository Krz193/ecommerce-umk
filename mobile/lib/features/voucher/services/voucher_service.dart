import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/voucher/models/store_voucher_model.dart';

final voucherServiceProvider = Provider<VoucherService>((ref) {
  return VoucherService();
});

class VoucherService {
  Future<List<StoreVoucherModel>> getStoreVouchers(String storeId) async {
    final response = await supabase
        .from('store_vouchers')
        .select()
        .eq('store_id', storeId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => StoreVoucherModel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<StoreVoucherModel> createVoucher(StoreVoucherModel voucher) async {
    final data = voucher.toMap();
    data.remove('used_count');

    final response = await supabase
        .from('store_vouchers')
        .insert(data)
        .select()
        .single();

    return StoreVoucherModel.fromMap(response);
  }

  Future<void> toggleVoucherStatus(String voucherId, bool isActive) async {
    await supabase
        .from('store_vouchers')
        .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', voucherId);
  }

  Future<void> deleteVoucher(String voucherId) async {
    await supabase.from('store_vouchers').delete().eq('id', voucherId);
  }

  /// Memvalidasi voucher dari sisi server (Zero Client Trust)
  Future<Map<String, dynamic>> validateVoucher({
    required String code,
    required String storeId,
    required int subtotal,
    List<Map<String, dynamic>> items = const [],
  }) async {
    final cleanCode = code.toUpperCase().trim();
    if (cleanCode.isEmpty) {
      return {'valid': false, 'message': 'Kode voucher tidak boleh kosong'};
    }

    try {
      final response = await supabase.rpc(
        'validate_and_apply_voucher',
        params: {
          'p_code': cleanCode,
          'p_store_id': storeId,
          'p_subtotal': subtotal,
          'p_items': items,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {
        'valid': false,
        'message': 'Gagal memeriksa voucher: ${e.toString().replaceAll('Exception: ', '')}',
      };
    }
  }
}
