class AppNotificationModel {
  final String id;
  final String userId;
  final String category; // 'transaction' | 'promo' | 'system'
  final String type;
  final String title;
  final String body;
  final String? targetRoute;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.type,
    required this.title,
    required this.body,
    this.targetRoute,
    this.data = const {},
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return AppNotificationModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      category: (json['category'] ?? 'system').toString(),
      type: (json['type'] ?? 'general').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      targetRoute: json['target_route']?.toString(),
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : const {},
      isRead: json['is_read'] == true,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())?.toLocal()
          : null,
      createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
    );
  }
}
