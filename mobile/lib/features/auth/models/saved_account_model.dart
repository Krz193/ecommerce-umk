class SavedAccountModel {
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String? role;
  final DateTime lastLoggedInAt;

  const SavedAccountModel({
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.role,
    required this.lastLoggedInAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'role': role,
      'lastLoggedInAt': lastLoggedInAt.toIso8601String(),
    };
  }

  factory SavedAccountModel.fromJson(Map<String, dynamic> json) {
    return SavedAccountModel(
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String?,
      lastLoggedInAt: json['lastLoggedInAt'] != null
          ? DateTime.tryParse(json['lastLoggedInAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  SavedAccountModel copyWith({
    String? email,
    String? fullName,
    String? avatarUrl,
    String? role,
    DateTime? lastLoggedInAt,
  }) {
    return SavedAccountModel(
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      lastLoggedInAt: lastLoggedInAt ?? this.lastLoggedInAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedAccountModel &&
          runtimeType == other.runtimeType &&
          email.toLowerCase() == other.email.toLowerCase();

  @override
  int get hashCode => email.toLowerCase().hashCode;
}
