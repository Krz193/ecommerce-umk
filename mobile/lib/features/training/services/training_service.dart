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
    await _supabase.from('training_participants').upsert({
      'training_id': trainingId,
      'store_id': storeId,
      'user_id': userId,
      'status': 'registered',
      'notes': notes,
      'registered_at': DateTime.now().toIso8601String(),
    }, onConflict: 'training_id,store_id');
  }
}
