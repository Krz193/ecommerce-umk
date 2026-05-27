import 'package:mobile/core/config/supabase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = supabase;

  // Current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Current user
  User? get currentUser => _supabase.auth.currentUser;

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
  }) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  // Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
