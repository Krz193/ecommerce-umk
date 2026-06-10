class AppUserModel {
  final String id;

  final String fullName;

  final String? username;

  final String? phone;

  final String? avatarUrl;

  final String role;

  AppUserModel({
    required this.id,
    required this.fullName,
    required this.username,
    required this.phone,
    required this.avatarUrl,
    required this.role,
  });

  bool get isBuyer => role == 'buyer';

  bool get isSeller => role == 'seller';

  bool get isAdmin => role == 'admin';

  factory AppUserModel.fromMap(Map<String, dynamic> map) {
    return AppUserModel(
      id: map['id'],
      fullName: map['full_name'],
      username: map['username'],
      phone: map['phone'],
      avatarUrl: map['avatar_url'],
      role: map['role'],
    );
  }
}
