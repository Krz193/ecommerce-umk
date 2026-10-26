class TrainingModel {
  final String id;
  final String title;
  final String? description;
  final String instructor;
  final DateTime scheduleAt;
  final String locationOrUrl;
  final int maxParticipants;
  final String status;
  final String? reportSummary;
  final List<String> documentationUrls;
  final String? materialUrl;
  final bool isRegistered;

  TrainingModel({
    required this.id,
    required this.title,
    this.description,
    required this.instructor,
    required this.scheduleAt,
    required this.locationOrUrl,
    required this.maxParticipants,
    required this.status,
    this.reportSummary,
    this.documentationUrls = const [],
    this.materialUrl,
    this.isRegistered = false,
  });

  factory TrainingModel.fromJson(
    Map<String, dynamic> json, {
    bool isRegistered = false,
  }) {
    final rawDocs = json['documentation_urls'];
    return TrainingModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      instructor: json['instructor'] as String? ?? 'Tim Ahli UMK',
      scheduleAt: DateTime.parse(json['schedule_at'] as String),
      locationOrUrl: json['location_or_url'] as String? ?? 'Online via Zoom',
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 50,
      status: json['status'] as String? ?? 'upcoming',
      reportSummary: json['report_summary'] as String?,
      documentationUrls: rawDocs is List
          ? rawDocs
                .map((item) => item.toString())
                .where((url) => url.isNotEmpty)
                .toList()
          : const [],
      materialUrl: json['material_url'] as String?,
      isRegistered: isRegistered,
    );
  }
}
