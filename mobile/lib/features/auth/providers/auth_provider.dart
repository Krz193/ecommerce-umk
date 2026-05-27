import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Auth service
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Auth state stream
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

// Current user
final currentUserProvider = Provider<User?>((ref) {
  return supabase.auth.currentUser;
});
