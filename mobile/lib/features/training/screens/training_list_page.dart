import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/store/providers/store_provider.dart';
import 'package:mobile/features/training/models/training_model.dart';
import 'package:mobile/features/training/providers/training_provider.dart';

class TrainingListPage extends ConsumerStatefulWidget {
  const TrainingListPage({super.key});

  @override
  ConsumerState<TrainingListPage> createState() => _TrainingListPageState();
}

class _TrainingListPageState extends ConsumerState<TrainingListPage> {
  String? registeringId;

  Future<void> handleRegister(TrainingModel training) async {
    final store = await ref.read(managedStoreProvider.future);
    final user = ref.read(currentUserProvider);

    if (store == null || user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hanya mitra toko UMK yang dapat mendaftar pelatihan.')),
      );
      return;
    }

    setState(() {
      registeringId = training.id;
    });

    try {
      final service = ref.read(trainingServiceProvider);
      await service.registerForTraining(
        trainingId: training.id,
        storeId: store.id,
        userId: user.id,
      );

      ref.invalidate(trainingsListProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Toko "${store.name}" berhasil terdaftar di "${training.title}"!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mendaftar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          registeringId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainingsAsync = ref.watch(trainingsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Program Pelatihan UMK'),
      ),
      body: trainingsAsync.when(
        data: (trainings) {
          if (trainings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum Ada Jadwal Pelatihan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Program pembinaan & webinar bisnis baru akan diumumkan di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(trainingsListProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trainings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final training = trainings[index];
                return buildTrainingCard(training);
              },
            ),
          );
        },
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget buildTrainingCard(TrainingModel training) {
    final isEnrolled = training.isRegistered;
    final isProcessing = registeringId == training.id;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isEnrolled ? Colors.green.shade300 : Colors.grey.shade200,
          width: isEnrolled ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: training.status == 'upcoming'
                        ? Colors.blue.shade50
                        : (training.status == 'completed' ? Colors.grey.shade100 : Colors.orange.shade50),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    training.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: training.status == 'upcoming'
                          ? Colors.blue.shade800
                          : (training.status == 'completed' ? Colors.grey.shade700 : Colors.orange.shade800),
                    ),
                  ),
                ),
                if (isEnrolled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Terdaftar',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              training.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (training.description != null && training.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                training.description!,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pemateri: ${training.instructor}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Jadwal: ${DateFormatter.formatDateTime(training.scheduleAt.toIso8601String())}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.videocam_outlined, size: 16, color: Colors.blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    training.locationOrUrl,
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: isEnrolled
                  ? OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Link pelatihan: ${training.locationOrUrl}')),
                        );
                      },
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Buka Info / Link Pelatihan'),
                    )
                  : ElevatedButton.icon(
                      onPressed: isProcessing ? null : () => handleRegister(training),
                      icon: isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.how_to_reg_outlined, size: 18),
                      label: const Text('Daftar Ikuti Pelatihan'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
