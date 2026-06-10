import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/order/services/order_status_service.dart';

final orderStatusServiceProvider = Provider<OrderStatusService>((ref) {
  return OrderStatusService();
});
