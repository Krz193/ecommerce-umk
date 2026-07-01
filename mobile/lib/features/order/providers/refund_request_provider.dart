import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/order/models/refund_request_model.dart';
import 'package:mobile/features/order/services/refund_request_service.dart';

final refundRequestServiceProvider = Provider<RefundRequestService>((ref) {
  return RefundRequestService();
});

final refundRequestsProvider = FutureProvider.autoDispose
    .family<List<RefundRequestModel>, String>((ref, orderId) async {
      final service = ref.read(refundRequestServiceProvider);

      return service.getRequests(orderId: orderId);
    });
