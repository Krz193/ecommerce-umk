import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/error_formatter.dart';
import 'package:mobile/features/order/widgets/order_error_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Order error formatting & safe UX', () {
    test(
      'formatUserFriendlyError hides PGRST116 raw details and translates not-found errors',
      () {
        const pgError = PostgrestException(
          message: 'Cannot coerce the result to a single JSON object',
          code: 'PGRST116',
          details: 'The result contains 0 rows',
        );
        expect(isNotFoundError(pgError), isTrue);
        final pgFormatted = formatUserFriendlyError(pgError);
        expect(
          pgFormatted,
          'Data tidak ditemukan atau Anda tidak lagi memiliki akses.',
        );
        expect(pgFormatted, isNot(contains('PGRST116')));
        expect(pgFormatted, isNot(contains('PostgrestException')));

        const notFound = ResourceNotFoundException(
          'Pesanan tidak ditemukan atau sudah tidak tersedia.',
        );
        expect(isNotFoundError(notFound), isTrue);
        expect(
          formatUserFriendlyError(notFound),
          'Pesanan tidak ditemukan atau sudah tidak tersedia.',
        );

        expect(
          formatUserFriendlyError(Exception('User not logged in')),
          'Sesi Anda telah berakhir. Silakan masuk kembali.',
        );
        expect(isNotFoundError(Exception('SocketException')), isFalse);
      },
    );

    testWidgets(
      'OrderErrorView renders friendly not-found copy and actions for PGRST116',
      (tester) async {
        var retried = false;
        var wentBack = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrderErrorView(
                error: const PostgrestException(
                  message: 'Cannot coerce the result to a single JSON object',
                  code: 'PGRST116',
                  details: 'The result contains 0 rows',
                ),
                onRetry: () => retried = true,
                onBack: () => wentBack = true,
              ),
            ),
          ),
        );

        expect(find.text('Pesanan Tidak Ditemukan'), findsOneWidget);
        expect(
          find.text('Data tidak ditemukan atau Anda tidak lagi memiliki akses.'),
          findsOneWidget,
        );
        expect(find.textContaining('PostgrestException'), findsNothing);
        expect(find.textContaining('PGRST116'), findsNothing);

        await tester.tap(find.text('Kembali'));
        await tester.tap(find.text('Coba Lagi'));
        expect(wentBack, isTrue);
        expect(retried, isTrue);
      },
    );

    testWidgets(
      'OrderErrorView renders custom ResourceNotFoundException and generic error copy',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrderErrorView(
                error: const ResourceNotFoundException(
                  'Pesanan tidak ditemukan atau sudah tidak tersedia untuk toko ini.',
                ),
                onRetry: () {},
                onBack: () {},
              ),
            ),
          ),
        );

        expect(find.text('Pesanan Tidak Ditemukan'), findsOneWidget);
        expect(
          find.text(
            'Pesanan tidak ditemukan atau sudah tidak tersedia untuk toko ini.',
          ),
          findsOneWidget,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrderErrorView(
                error: Exception('SocketException: Network is unreachable'),
                onRetry: () {},
                onBack: () {},
              ),
            ),
          ),
        );

        expect(find.text('Gagal Memuat Pesanan'), findsOneWidget);
        expect(
          find.text(
            'Gagal terhubung ke server. Silakan periksa koneksi internet Anda dan coba lagi.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
