import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/auth/models/saved_account_model.dart';
import 'package:mobile/features/auth/services/saved_account_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavedAccountModel', () {
    test('toJson and fromJson preserves fields correctly', () {
      final now = DateTime.now();
      final account = SavedAccountModel(
        email: 'test@example.com',
        fullName: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
        role: 'Pelaku UMK',
        lastLoggedInAt: now,
      );

      final json = account.toJson();
      final reconstructed = SavedAccountModel.fromJson(json);

      expect(reconstructed.email, equals(account.email));
      expect(reconstructed.fullName, equals(account.fullName));
      expect(reconstructed.avatarUrl, equals(account.avatarUrl));
      expect(reconstructed.role, equals(account.role));
      expect(
        reconstructed.lastLoggedInAt.millisecondsSinceEpoch,
        equals(account.lastLoggedInAt.millisecondsSinceEpoch),
      );
    });

    test('equality compares case-insensitive email', () {
      final acc1 = SavedAccountModel(
        email: 'User@Example.com',
        fullName: 'User One',
        lastLoggedInAt: DateTime.now(),
      );

      final acc2 = SavedAccountModel(
        email: 'user@example.com',
        fullName: 'User Two',
        lastLoggedInAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      expect(acc1, equals(acc2));
    });
  });

  group('SavedAccountService (Encrypted Storage)', () {
    late SavedAccountService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      service = SavedAccountService();
    });

    test('saves account in encrypted storage without writing to SharedPreferences', () async {
      await service.saveOrUpdateAccount(
        email: 'first@example.com',
        fullName: 'First User',
      );

      await Future.delayed(const Duration(milliseconds: 15));

      await service.saveOrUpdateAccount(
        email: 'second@example.com',
        fullName: 'Second User',
      );

      final accounts = await service.getSavedAccounts();
      expect(accounts.length, equals(2));
      expect(accounts.first.email, equals('second@example.com'));
      expect(accounts.last.email, equals('first@example.com'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('saved_login_accounts_v1'), isFalse);
    });

    test('migrates legacy SharedPreferences plaintext entries and purges plaintext', () async {
      final legacyAccount = SavedAccountModel(
        email: 'legacy@example.com',
        fullName: 'Legacy User',
        lastLoggedInAt: DateTime.now(),
      );

      SharedPreferences.setMockInitialValues({
        'saved_login_accounts_v1': [jsonEncode(legacyAccount.toJson())],
      });
      FlutterSecureStorage.setMockInitialValues({});
      final migrationService = SavedAccountService();

      final accounts = await migrationService.getSavedAccounts();
      expect(accounts.length, equals(1));
      expect(accounts.first.email, equals('legacy@example.com'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('saved_login_accounts_v1'), isFalse);
    });

    test('re-saving existing account moves it to the top without duplicates', () async {
      await service.saveOrUpdateAccount(
        email: 'user1@example.com',
        fullName: 'User 1',
      );

      await Future.delayed(const Duration(milliseconds: 15));

      await service.saveOrUpdateAccount(
        email: 'user2@example.com',
        fullName: 'User 2',
      );

      await Future.delayed(const Duration(milliseconds: 15));

      await service.saveOrUpdateAccount(
        email: 'USER1@example.com',
        fullName: 'User 1 Updated',
      );

      final accounts = await service.getSavedAccounts();
      expect(accounts.length, equals(2));
      expect(accounts.first.email, equals('USER1@example.com'));
      expect(accounts.first.fullName, equals('User 1 Updated'));
      expect(accounts.last.email, equals('user2@example.com'));
    });

    test('removes specific account from cache', () async {
      await service.saveOrUpdateAccount(
        email: 'delete_me@example.com',
        fullName: 'Delete Me',
      );
      await service.saveOrUpdateAccount(
        email: 'keep_me@example.com',
        fullName: 'Keep Me',
      );

      await service.removeAccount('delete_me@example.com');

      final accounts = await service.getSavedAccounts();
      expect(accounts.length, equals(1));
      expect(accounts.first.email, equals('keep_me@example.com'));
    });

    test('clears all accounts', () async {
      await service.saveOrUpdateAccount(
        email: 'user1@example.com',
        fullName: 'User 1',
      );
      await service.saveOrUpdateAccount(
        email: 'user2@example.com',
        fullName: 'User 2',
      );

      await service.clearAll();

      final accounts = await service.getSavedAccounts();
      expect(accounts, isEmpty);
    });
  });
}
