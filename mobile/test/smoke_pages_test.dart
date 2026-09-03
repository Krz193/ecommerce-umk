import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/feedback/screens/feedback_page.dart';
import 'package:mobile/features/training/models/training_model.dart';
import 'package:mobile/features/training/providers/training_provider.dart';
import 'package:mobile/features/training/screens/training_list_page.dart';

void main() {
  group('Smoke Test - Anti Fatal Solid Crash Screen', () {
    test('ErrorWidget.builder produces a valid fallback widget on error', () {
      final errorDetails = FlutterErrorDetails(exception: Exception('Simulated render error'));
      final errorWidget = ErrorWidget.builder(errorDetails);
      expect(errorWidget, isA<Widget>());
    });

    testWidgets('TrainingListPage renders cleanly when empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trainingsListProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: TrainingListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Program Pelatihan UMK'), findsOneWidget);
      expect(find.text('Belum Ada Jadwal Pelatihan'), findsOneWidget);
    });

    testWidgets('TrainingListPage renders cleanly with populated trainings', (tester) async {
      final sampleTrainings = [
        TrainingModel(
          id: 'test-1',
          title: 'Strategi Digital Marketing UMK',
          description: 'Pelatihan optimasi omset online',
          instructor: 'Budi Santoso',
          scheduleAt: DateTime.now().add(const Duration(days: 2)),
          locationOrUrl: 'Online via Zoom',
          maxParticipants: 50,
          status: 'upcoming',
          isRegistered: false,
        ),
        TrainingModel(
          id: 'test-2',
          title: 'Foto Produk HP Berkualitas',
          description: 'Foto produk estetik',
          instructor: 'Siti Rahma',
          scheduleAt: DateTime.now().add(const Duration(days: 5)),
          locationOrUrl: 'Ruang Pelatihan 1',
          maxParticipants: 30,
          status: 'upcoming',
          isRegistered: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trainingsListProvider.overrideWith((ref) async => sampleTrainings),
          ],
          child: const MaterialApp(
            home: TrainingListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Strategi Digital Marketing UMK'), findsOneWidget);
      expect(find.text('Foto Produk HP Berkualitas'), findsOneWidget);
      expect(find.text('Daftar Ikuti Pelatihan'), findsOneWidget);
      expect(find.text('Terdaftar'), findsOneWidget);
    });

    testWidgets('FeedbackPage renders cleanly with inputs and categories', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: FeedbackPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pusat Bantuan & Masukan'), findsOneWidget);
      expect(find.text('Kirim Masukan'), findsOneWidget);
    });
  });
}
