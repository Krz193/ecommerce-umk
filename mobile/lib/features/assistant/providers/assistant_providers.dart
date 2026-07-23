import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/assistant/models/assistance_log_model.dart';
import 'package:mobile/features/assistant/models/assistant_profile_model.dart';
import 'package:mobile/features/assistant/models/store_content_model.dart';
import 'package:mobile/features/assistant/services/assistant_service.dart';

final assistantServiceProvider = Provider<AssistantService>((ref) {
  return AssistantService();
});

final assistantProfileProvider =
    FutureProvider.autoDispose<AssistantProfileModel?>((ref) async {
      final service = ref.watch(assistantServiceProvider);
      return service.getAssistantProfile();
    });

final assignedStoresProvider =
    FutureProvider.autoDispose<List<AssignedStoreInfo>>((ref) async {
      final service = ref.watch(assistantServiceProvider);
      return service.getAssignedStores();
    });

class SelectedStoreNotifier extends Notifier<AssignedStoreInfo?> {
  @override
  AssignedStoreInfo? build() => null;

  void selectStore(AssignedStoreInfo store) {
    state = store;
  }
}

final selectedStoreProvider =
    NotifierProvider.autoDispose<SelectedStoreNotifier, AssignedStoreInfo?>(
      SelectedStoreNotifier.new,
    );

final assistanceLogsProvider = FutureProvider.autoDispose
    .family<List<AssistanceLogModel>, String?>((ref, storeId) async {
      final service = ref.watch(assistantServiceProvider);
      return service.getAssistanceLogs(storeId: storeId);
    });

final storeContentsProvider = FutureProvider.autoDispose
    .family<List<StoreContentModel>, String>((ref, storeId) async {
      final service = ref.watch(assistantServiceProvider);
      return service.getStoreContents(storeId: storeId);
    });
