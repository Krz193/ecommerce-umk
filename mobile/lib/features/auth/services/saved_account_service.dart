import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/auth/models/saved_account_model.dart';

class SavedAccountService {
  static const String _storageKey = 'saved_login_accounts_v1';
  static const int _maxAccounts = 10;

  Future<List<SavedAccountModel>> getSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey);
      if (rawList == null || rawList.isEmpty) {
        return [];
      }

      final accounts = <SavedAccountModel>[];
      for (final item in rawList) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          accounts.add(SavedAccountModel.fromJson(map));
        } catch (_) {
          // Skip corrupted item
        }
      }

      // Sort by latest login date
      accounts.sort((a, b) => b.lastLoggedInAt.compareTo(a.lastLoggedInAt));
      return accounts;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveOrUpdateAccount({
    required String email,
    required String fullName,
    String? avatarUrl,
    String? role,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentAccounts = await getSavedAccounts();

      final normalizedEmail = email.trim().toLowerCase();
      currentAccounts.removeWhere(
        (acc) => acc.email.trim().toLowerCase() == normalizedEmail,
      );

      final newAccount = SavedAccountModel(
        email: email.trim(),
        fullName: fullName.trim().isEmpty ? email.trim() : fullName.trim(),
        avatarUrl: avatarUrl,
        role: role,
        lastLoggedInAt: DateTime.now(),
      );

      currentAccounts.insert(0, newAccount);

      // Keep at most _maxAccounts
      final limited = currentAccounts.take(_maxAccounts).toList();

      final stringList =
          limited.map((acc) => jsonEncode(acc.toJson())).toList();
      await prefs.setStringList(_storageKey, stringList);
    } catch (_) {
      // Fail gracefully without crashing
    }
  }

  Future<void> removeAccount(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentAccounts = await getSavedAccounts();

      final normalizedEmail = email.trim().toLowerCase();
      currentAccounts.removeWhere(
        (acc) => acc.email.trim().toLowerCase() == normalizedEmail,
      );

      final stringList =
          currentAccounts.map((acc) => jsonEncode(acc.toJson())).toList();
      await prefs.setStringList(_storageKey, stringList);
    } catch (_) {
      // Fail gracefully
    }
  }

  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Fail gracefully
    }
  }
}
