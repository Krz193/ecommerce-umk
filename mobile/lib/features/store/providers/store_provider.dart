import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/store/models/store_model.dart';
import 'package:mobile/features/store/services/store_service.dart';

final storeServiceProvider = Provider<StoreService>((ref) {
  return StoreService();
});

final myStoreProvider = FutureProvider.autoDispose<StoreModel?>((ref) async {
  final storeService = ref.read(storeServiceProvider);

  return storeService.getMyStore();
});
