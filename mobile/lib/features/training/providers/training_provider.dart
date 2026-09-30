import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/providers/store_provider.dart';
import 'package:mobile/features/training/models/training_model.dart';
import 'package:mobile/features/training/services/training_service.dart';

final trainingServiceProvider = Provider<TrainingService>((ref) {
  return TrainingService();
});

final trainingsListProvider = FutureProvider.autoDispose<List<TrainingModel>>((
  ref,
) async {
  final service = ref.watch(trainingServiceProvider);
  final store = await ref.watch(managedStoreProvider.future);
  return service.getTrainings(storeId: store?.id);
});
