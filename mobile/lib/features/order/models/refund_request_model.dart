class RefundRequestModel {
  final String id;
  final String orderId;
  final String requestType;
  final String requesterRole;
  final String reason;
  final String status;
  final String? adminNotes;
  final DateTime requestedAt;
  final DateTime? resolvedAt;

  const RefundRequestModel({
    required this.id,
    required this.orderId,
    required this.requestType,
    required this.requesterRole,
    required this.reason,
    required this.status,
    this.adminNotes,
    required this.requestedAt,
    this.resolvedAt,
  });

  bool get isActive => !['resolved', 'rejected'].contains(status);

  factory RefundRequestModel.fromJson(Map<String, dynamic> json) {
    return RefundRequestModel(
      id: json['id'],
      orderId: json['order_id'],
      requestType: json['request_type'] ?? 'refund',
      requesterRole: json['requester_role'] ?? 'admin',
      reason: json['reason'],
      status: json['status'],
      adminNotes: json['admin_notes'],
      requestedAt: DateTime.parse(json['requested_at']),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
    );
  }
}
