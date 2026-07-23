class OrderPaymentModel {
  final String id;

  final String status;

  final String? expiredAt;

  final String? providerTransactionId;

  final Map<String, dynamic>? rawResponse;

  OrderPaymentModel({
    required this.id,
    required this.status,
    required this.expiredAt,
    required this.providerTransactionId,
    required this.rawResponse,
  });

  factory OrderPaymentModel.fromJson(Map<String, dynamic> json) {
    return OrderPaymentModel(
      id: json['id'],
      status: json['status'],
      expiredAt: json['expired_at'],
      providerTransactionId: json['provider_transaction_id'],
      rawResponse: json['raw_response'],
    );
  }
}
