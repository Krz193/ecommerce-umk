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
  // Make this provider reactive to auth state changes so consumers
  // don't hold a stale User after sign-out/sign-in.
  ref.watch(authStateProvider);

  return supabase.auth.currentUser;
});
