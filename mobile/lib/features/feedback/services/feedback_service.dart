import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/feedback/models/system_feedback_model.dart';

class FeedbackService {
  /// Submit new feedback to Supabase
  Future<SystemFeedbackModel> submitFeedback({
    required String category,
    required String subject,
    required String message,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Pengguna belum login. Silakan login terlebih dahulu.');
    }

    // Fetch user profile role if available
    String role = 'buyer';
    try {
      final profileRes = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      if (profileRes != null && profileRes['role'] != null) {
        role = profileRes['role'];
      }
    } catch (_) {
      // default to buyer
    }

    final payload = {
      'user_id': user.id,
      'user_role': role,
      'category': category,
      'subject': subject.trim(),
      'message': message.trim(),
      'status': 'pending',
    };

    final res = await supabase
        .from('system_feedbacks')
        .insert(payload)
        .select()
        .single();

    return SystemFeedbackModel.fromMap(res);
  }

  /// Get user's feedback history
  Future<List<SystemFeedbackModel>> getUserFeedbacks() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final res = await supabase
        .from('system_feedbacks')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (res as List).map((e) => SystemFeedbackModel.fromMap(e)).toList();
  }
}
