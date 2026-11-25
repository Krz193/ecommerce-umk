import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/auth/models/saved_account_model.dart';

class SavedAccountService {
  static const String _legacyPlaintextStorageKey = 'saved_login_accounts_v1';
  static const String _secureStorageKey = 'secure_saved_login_accounts_v2';
  static const int _maxAccounts = 10;

  final FlutterSecureStorage _secureStorage;

  SavedAccountService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// One-way migration that moves any legacy SharedPreferences entries into
  /// encrypted platform storage and immediately purges plaintext entries.
  Future<void> _migrateAndPurgeLegacyPlaintext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_legacyPlaintextStorageKey)) {
        return;
      }

      final legacyList = prefs.getStringList(_legacyPlaintextStorageKey);
      await prefs.remove(_legacyPlaintextStorageKey);

      if (legacyList != null && legacyList.isNotEmpty) {
        final existingEncrypted = await _secureStorage.read(
          key: _secureStorageKey,
        );
        if (existingEncrypted == null || existingEncrypted.isEmpty) {
          await _secureStorage.write(
            key: _secureStorageKey,
            value: jsonEncode(legacyList),
          );
        }
      }
    } catch (_) {
      // Best-effort purge of legacy plaintext storage
    }
  }

  Future<List<SavedAccountModel>> getSavedAccounts() async {
    try {
      await _migrateAndPurgeLegacyPlaintext();

      final rawJson = await _secureStorage.read(key: _secureStorageKey);
      if (rawJson == null || rawJson.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return [];

      final accounts = <SavedAccountModel>[];
      for (final item in decoded) {
        try {
          final map = item is String
              ? jsonDecode(item) as Map<String, dynamic>
              : Map<String, dynamic>.from(item as Map);
          accounts.add(SavedAccountModel.fromJson(map));
        } catch (_) {
          // Skip corrupted item
        }
      }

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

      final limited = currentAccounts.take(_maxAccounts).toList();
      final serialized = jsonEncode(limited.map((acc) => acc.toJson()).toList());

      await _secureStorage.write(key: _secureStorageKey, value: serialized);
    } catch (_) {
      // Fail gracefully without crashing
    }
  }

  Future<void> removeAccount(String email) async {
    try {
      final currentAccounts = await getSavedAccounts();

      final normalizedEmail = email.trim().toLowerCase();
      currentAccounts.removeWhere(
        (acc) => acc.email.trim().toLowerCase() == normalizedEmail,
      );

      final serialized = jsonEncode(
        currentAccounts.map((acc) => acc.toJson()).toList(),
      );
      await _secureStorage.write(key: _secureStorageKey, value: serialized);
    } catch (_) {
      // Fail gracefully
    }
  }

  Future<void> clearAll() async {
    try {
      await _migrateAndPurgeLegacyPlaintext();
      await _secureStorage.delete(key: _secureStorageKey);
    } catch (_) {
      // Fail gracefully
    }
  }
}
