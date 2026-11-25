import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/csv_exporter.dart';
import 'package:mobile/features/account/account_page.dart';
import 'package:mobile/features/account/change_password_page.dart';
import 'package:mobile/features/auth/models/app_user_model.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/order/order_detail_page.dart';
import 'package:mobile/features/order/seller_order_detail_page.dart';
import 'package:mobile/features/order/widgets/shipment_tracking_section.dart';
import 'package:mobile/features/store/models/store_model.dart';
import 'package:mobile/features/store/providers/store_provider.dart';
import 'package:mobile/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Batch 1 Security & Financial Integrity Tests', () {
    test('escapeCsvCell neutralizes =, +, -, @, tab, and CR formula injection prefixes', () {
      expect(escapeCsvCell('=1+1'), "'=1+1");
      expect(escapeCsvCell('+628123456789'), "'+628123456789");
      expect(escapeCsvCell('-10000'), "'-10000");
      expect(escapeCsvCell('@SUM(A1:A5)'), "'@SUM(A1:A5)");
      expect(escapeCsvCell('  =HYPERLINK("http://evil.example")'),
          '"\'  =HYPERLINK(""http://evil.example"")"');
      expect(escapeCsvCell('\t=CMD()'), "'\t=CMD()");
      expect(escapeCsvCell('Kopi Bali, 250g'), '"Kopi Bali, 250g"');
      expect(escapeCsvCell('Normal Product'), 'Normal Product');

      final csv = buildCsvContent([
        ['Name', 'Phone'],
        ['=Evil', '+628111'],
      ]);
      expect(csv, "Name,Phone\n'=Evil,'+628111");
    });

    test('shouldInvalidateOnAuthChange ignores tokenRefreshed and triggers on signOut/account switch', () {
      expect(
        shouldInvalidateOnAuthChange(
          event: AuthChangeEvent.tokenRefreshed,
          previousUserId: 'user-1',
          nextUserId: 'user-1',
        ),
        isFalse,
      );

      expect(
        shouldInvalidateOnAuthChange(
          event: AuthChangeEvent.initialSession,
          previousUserId: null,
          nextUserId: 'user-1',
        ),
        isFalse,
      );

      expect(
        shouldInvalidateOnAuthChange(
          event: AuthChangeEvent.signedOut,
          previousUserId: 'user-1',
          nextUserId: null,
        ),
        isTrue,
      );

      expect(
        shouldInvalidateOnAuthChange(
          event: AuthChangeEvent.signedIn,
          previousUserId: 'user-1',
          nextUserId: 'user-2',
        ),
        isTrue,
      );

      expect(
        shouldInvalidateOnAuthChange(
          event: AuthChangeEvent.userUpdated,
          previousUserId: 'user-1',
          nextUserId: 'user-1',
        ),
        isFalse,
      );
    });

    test('LocalShippingRateTier validates distance ranges and StoreModel parses local shipping', () {
      final validTiers = const [
        LocalShippingRateTier(minKm: 0, maxKm: 5, price: 10000),
        LocalShippingRateTier(minKm: 5, maxKm: 12, price: 18000),
      ];
      expect(LocalShippingRateTier.validateTiers(validTiers), isNull);

      final overlappingTiers = const [
        LocalShippingRateTier(minKm: 0, maxKm: 6, price: 10000),
        LocalShippingRateTier(minKm: 5, maxKm: 10, price: 18000),
      ];
      expect(LocalShippingRateTier.validateTiers(overlappingTiers), isNotNull);

      final invalidRange = const [
        LocalShippingRateTier(minKm: 5, maxKm: 5, price: 10000),
      ];
      expect(LocalShippingRateTier.validateTiers(invalidRange), isNotNull);

      final negativePrice = const [
        LocalShippingRateTier(minKm: 0, maxKm: 5, price: -1000),
      ];
      expect(LocalShippingRateTier.validateTiers(negativePrice), isNotNull);

      final store = StoreModel.fromMap({
        'id': 'store-local-1',
        'owner_id': 'owner-1',
        'name': 'Toko UMK Mandiri',
        'slug': 'toko-umk-mandiri',
        'description': 'UMK',
        'phone': '08123456789',
        'address': 'Jl. Raya No. 1',
        'latitude': -8.65,
        'longitude': 115.21,
        'local_ojek_enabled': true,
        'local_ojek_rates': [
          {'min_km': 0, 'max_km': 5, 'price': 10000},
        ],
        'local_ekspedisi_enabled': false,
        'local_ekspedisi_rates': [],
        'status': 'active',
      });

      expect(store.hasValidCoordinates, isTrue);
      expect(store.localOjekEnabled, isTrue);
      expect(store.localOjekRates.length, 1);
      expect(store.localOjekRates.first.price, 10000);
      expect(store.localEkspedisiEnabled, isFalse);
    });

    testWidgets('ChangePasswordPage requires current password field for re-authentication', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kata Sandi Saat Ini'), findsOneWidget);
      expect(find.text('Kata Sandi Baru'), findsOneWidget);
      expect(find.text('Konfirmasi Kata Sandi Baru'), findsOneWidget);

      await tester.tap(find.text('Simpan Kata Sandi Baru'));
      await tester.pumpAndSettle();

      expect(find.text('Masukkan kata sandi saat ini'), findsOneWidget);
    });

    testWidgets('AccountPage hides Mitra Logistik section for non-logistics roles', (tester) async {
      final buyerUser = AppUserModel(
        id: 'buyer-1',
        fullName: 'Budi Pembeli',
        email: 'budi@example.com',
        phone: '08123456789',
        avatarUrl: null,
        role: 'buyer',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUserProvider.overrideWith((ref) async => buyerUser),
            myStoreProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(home: AccountPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('Mitra Logistik & Pengantaran'), findsNothing);
      expect(find.text('Portal Driver Ojek'), findsNothing);
      expect(find.text('Portal Kurir Ekspedisi'), findsNothing);
    });

    testWidgets('AccountPage shows only matching portal for ojek role', (tester) async {
      final ojekUser = AppUserModel(
        id: 'ojek-1',
        fullName: 'Agus Driver',
        email: 'agus@example.com',
        phone: '08129876543',
        avatarUrl: null,
        role: 'ojek',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUserProvider.overrideWith((ref) async => ojekUser),
            myStoreProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(home: AccountPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Portal Driver Ojek'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Portal Driver Ojek'), findsOneWidget);
      expect(find.text('Portal Kurir Ekspedisi'), findsNothing);
    });

    test('Refund eligibility strictly blocks unpaid (paymentStatus == pending) orders for buyer and seller', () {
      expect(isOrderEligibleForBuyerRefund(status: 'pending', paymentStatus: 'pending'), isFalse);
      expect(isOrderEligibleForBuyerRefund(status: 'processing', paymentStatus: 'pending'), isFalse);
      expect(isOrderEligibleForBuyerRefund(status: 'processing', paymentStatus: 'expired'), isFalse);
      expect(isOrderEligibleForBuyerRefund(status: 'processing', paymentStatus: 'paid'), isTrue);
      expect(isOrderEligibleForBuyerRefund(status: 'shipped', paymentStatus: 'paid'), isTrue);
      expect(isOrderEligibleForBuyerRefund(status: 'delivered', paymentStatus: 'paid'), isTrue);
      expect(isOrderEligibleForBuyerRefund(status: 'completed', paymentStatus: 'paid'), isFalse);
      expect(isOrderEligibleForBuyerRefund(status: 'cancelled', paymentStatus: 'paid'), isFalse);

      expect(isOrderEligibleForSellerRefund(status: 'pending', paymentStatus: 'pending'), isFalse);
      expect(isOrderEligibleForSellerRefund(status: 'processing', paymentStatus: 'pending'), isFalse);
      expect(isOrderEligibleForSellerRefund(status: 'processing', paymentStatus: 'paid'), isTrue);
      expect(isOrderEligibleForSellerRefund(status: 'shipped', paymentStatus: 'paid'), isTrue);
      expect(isOrderEligibleForSellerRefund(status: 'completed', paymentStatus: 'paid'), isFalse);
      expect(isOrderEligibleForSellerRefund(status: 'cancelled', paymentStatus: 'paid'), isFalse);
    });

    test('formatOrderTrackingStatus maps ready_to_ship cleanly', () {
      expect(formatOrderTrackingStatus('ready_to_ship'), 'Siap Dijemput Kurir Toko');
    });
  });
}
