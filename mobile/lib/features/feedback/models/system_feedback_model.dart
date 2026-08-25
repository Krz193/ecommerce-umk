class SystemFeedbackModel {
  final String id;
  final String userId;
  final String userRole;
  final String category;
  final String subject;
  final String message;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  SystemFeedbackModel({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.category,
    required this.subject,
    required this.message,
    required this.status,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SystemFeedbackModel.fromMap(Map<String, dynamic> map) {
    return SystemFeedbackModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      userRole: map['user_role'] ?? 'buyer',
      category: map['category'] ?? 'saran',
      subject: map['subject'] ?? '',
      message: map['message'] ?? '',
      status: map['status'] ?? 'pending',
      adminNotes: map['admin_notes'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'user_role': userRole,
      'category': category,
      'subject': subject,
      'message': message,
      'status': status,
      if (adminNotes != null) 'admin_notes': adminNotes,
    };
  }

  String get categoryLabel {
    switch (category) {
      case 'saran':
        return 'Saran';
      case 'masukan':
        return 'Kritik & Masukan';
      case 'kendala_sistem':
        return 'Kendala Sistem / Bug';
      case 'bantuan_operasional':
        return 'Bantuan Operasional';
      case 'lainnya':
      default:
        return 'Lainnya';
    }
  }
}
