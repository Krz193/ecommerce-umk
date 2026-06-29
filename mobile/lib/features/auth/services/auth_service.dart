import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/auth/models/app_user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = supabase;

  // Current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Current user
  User? get currentUser => _supabase.auth.currentUser;

  Future<AppUserModel?> getAppUser() async {
    final user = currentUser;

    if (user == null) {
      return null;
    }

    final response = await _supabase
        .from('users')
        .select('id, full_name, username, phone, avatar_url, role')
        .eq('id', user.id)
        .single();

    return AppUserModel.fromMap(response);
  }

  Future<AppUserModel> becomeSeller() async {
    final response = await _supabase.rpc('become_seller');

    return AppUserModel.fromMap(Map<String, dynamic>.from(response));
  }

  Future<AppUserModel> updateProfile({
    required String fullName,
    String? username,
    String? phone,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      final response = await _supabase
          .from('users')
          .update({
            'full_name': fullName,
            'username': blankToNull(username),
            'phone': blankToNull(phone),
          })
          .eq('id', user.id)
          .select('id, full_name, username, phone, avatar_url, role')
          .single();

      return AppUserModel.fromMap(response);
    } on PostgrestException catch (error) {
      if (error.code == '23505' && error.message.contains('users_username_key')) {
        throw Exception('Username is already used');
      }

      throw Exception(error.message);
    }
  }

  String? blankToNull(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  // Login
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Register
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) async {
    return await _supabase.auth.signUp(
      email: email,

      password: password,

      data: {'full_name': fullName, 'username': username},
    );
  }

  // Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
