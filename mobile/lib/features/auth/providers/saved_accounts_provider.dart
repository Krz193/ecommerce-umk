import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/auth/models/saved_account_model.dart';
import 'package:mobile/features/auth/services/saved_account_service.dart';

final savedAccountServiceProvider = Provider<SavedAccountService>((ref) {
  return SavedAccountService();
});

class SavedAccountsNotifier extends AsyncNotifier<List<SavedAccountModel>> {
  @override
  Future<List<SavedAccountModel>> build() async {
    final service = ref.read(savedAccountServiceProvider);
    return service.getSavedAccounts();
  }

  Future<void> saveAccount({
    required String email,
    required String fullName,
    String? avatarUrl,
    String? role,
  }) async {
    final service = ref.read(savedAccountServiceProvider);
    await service.saveOrUpdateAccount(
      email: email,
      fullName: fullName,
      avatarUrl: avatarUrl,
      role: role,
    );
    state = AsyncData(await service.getSavedAccounts());
  }

  Future<void> removeAccount(String email) async {
    final service = ref.read(savedAccountServiceProvider);
    await service.removeAccount(email);
    state = AsyncData(await service.getSavedAccounts());
  }

  Future<void> clearAll() async {
    final service = ref.read(savedAccountServiceProvider);
    await service.clearAll();
    state = const AsyncData([]);
  }
}

final savedAccountsProvider =
    AsyncNotifierProvider<SavedAccountsNotifier, List<SavedAccountModel>>(() {
  return SavedAccountsNotifier();
});
