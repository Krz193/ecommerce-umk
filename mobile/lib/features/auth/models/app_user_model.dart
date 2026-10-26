import 'package:mobile/core/config/supabase_provider.dart';

class AppUserModel {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String role;

  AppUserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.role,
  });

  bool get isBuyer => role == 'buyer';
  bool get isSeller => role == 'seller';
  bool get isAssistant => role == 'assistant';
  bool get isEkspedisi => role == 'ekspedisi';
  bool get isOjek => role == 'ojek';
  bool get isAdmin => role == 'admin';

  String get roleBadgeLabel {
    switch (role) {
      case 'seller':
        return 'Pelaku UMK';
      case 'assistant':
        return 'Pendamping UMK';
      case 'ekspedisi':
        return 'Mitra Ekspedisi';
      case 'ojek':
        return 'Driver Ojek';
      case 'admin':
        return 'Administrator';
      default:
        return 'Pembeli';
    }
  }

  factory AppUserModel.fromMap(Map<String, dynamic> map) {
    String currentEmail = '';
    try {
      currentEmail = supabase.auth.currentUser?.email ?? '';
    } catch (_) {
      // Supabase instance might not be initialized in headless unit tests
    }

    return AppUserModel(
      id: map['id'],
      fullName: map['full_name'] ?? '',
      email: map['email'] ?? currentEmail,
      phone: map['phone'],
      avatarUrl: map['avatar_url'],
      role: map['role'] ?? 'buyer',
    );
  }
}
