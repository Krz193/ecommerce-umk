import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/order/models/refund_request_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RefundRequestException implements Exception {
  final String message;

  const RefundRequestException(this.message);

  @override
  String toString() => message;
}

class RefundRequestService {
  final SupabaseClient _supabase = supabase;

  Future<List<RefundRequestModel>> getRequests({
    required String orderId,
  }) async {
    try {
      final response = await _supabase
          .from('refunds')
          .select()
          .eq('order_id', orderId)
          .order('requested_at', ascending: false);

      return response
          .map<RefundRequestModel>((json) => RefundRequestModel.fromJson(json))
          .toList();
    } on PostgrestException catch (error) {
      throw RefundRequestException(error.message);
    }
  }

  Future<void> createRequest({
    required String orderId,
    required String requestType,
    required String requesterRole,
    required String reason,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      throw const RefundRequestException('Login required');
    }

    if (reason.trim().isEmpty) {
      throw const RefundRequestException('Reason required');
    }

    try {
      await _supabase.from('refunds').insert({
        'order_id': orderId,
        'request_type': requestType,
        'requester_role': requesterRole,
        'requested_by': userId,
        'reason': reason.trim(),
        'status': 'requested',
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const RefundRequestException(
          'A cancellation/refund request is already active for this order',
        );
      }

      if (error.code == '42501') {
        throw const RefundRequestException(
          'This order is not eligible for cancellation/refund request',
        );
      }

      throw RefundRequestException(error.message);
    }
  }
}
