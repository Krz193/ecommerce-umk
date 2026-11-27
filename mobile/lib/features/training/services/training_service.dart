import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/training/models/training_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrainingService {
  final SupabaseClient _supabase = supabase;

  Future<List<TrainingModel>> getTrainings({String? storeId}) async {
    final trainingsRes = await _supabase
        .from('trainings')
        .select()
        .order('schedule_at', ascending: true);

    Set<String> registeredTrainingIds = {};
    if (storeId != null) {
      final participantsRes = await _supabase
          .from('training_participants')
          .select('training_id')
          .eq('store_id', storeId);

      registeredTrainingIds = (participantsRes as List)
          .map((p) => p['training_id'] as String)
          .toSet();
    }

    return (trainingsRes as List).map<TrainingModel>((item) {
      final id = item['id'] as String;
      return TrainingModel.fromJson(
        item as Map<String, dynamic>,
        isRegistered: registeredTrainingIds.contains(id),
      );
    }).toList();
  }

  Future<void> registerForTraining({
    required String trainingId,
    required String storeId,
    required String userId,
    String? notes,
  }) async {
    final training = await _supabase
        .from('trainings')
        .select('id, schedule_at, max_participants, status')
        .eq('id', trainingId)
        .maybeSingle();

    if (training == null) {
      throw Exception('Pelatihan tidak ditemukan');
    }

    final status = training['status']?.toString();
    if (status == 'cancelled' || status == 'completed') {
      throw Exception('Pendaftaran pelatihan sudah ditutup');
    }

    final scheduleAt = DateTime.tryParse(
      training['schedule_at']?.toString() ?? '',
    );
    if (scheduleAt != null && scheduleAt.isBefore(DateTime.now())) {
      throw Exception('Jadwal pelatihan sudah lewat');
    }

    final existing = await _supabase
        .from('training_participants')
        .select('id, status')
        .eq('training_id', trainingId)
        .eq('store_id', storeId)
        .maybeSingle();

    if (existing != null) {
      final existingStatus = existing['status']?.toString();
      if (existingStatus == 'attended') {
        throw Exception('Anda sudah tercatat hadir pada pelatihan ini');
      }
      if (existingStatus == 'cancelled') {
        throw Exception('Pendaftaran Anda sebelumnya telah dibatalkan');
      }
      throw Exception('Toko Anda sudah terdaftar pada pelatihan ini');
    }

    final maxParticipants =
        (training['max_participants'] as num?)?.toInt() ?? 0;
    if (maxParticipants > 0) {
      final activeParticipants = await _supabase
          .from('training_participants')
          .select('id')
          .eq('training_id', trainingId)
          .neq('status', 'cancelled');

      if ((activeParticipants as List).length >= maxParticipants) {
        throw Exception('Kuota peserta pelatihan sudah penuh');
      }
    }

    await _supabase.from('training_participants').insert({
      'training_id': trainingId,
      'store_id': storeId,
      'user_id': userId,
      'status': 'registered',
      'notes': notes,
      'registered_at': DateTime.now().toIso8601String(),
    });
  }
}
