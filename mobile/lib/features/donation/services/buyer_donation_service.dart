import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/config/supabase_provider.dart';

class DonationPaymentChannelOption {
  final String code;
  final String label;
  final String shortLabel;
  final String category; // 'va' | 'ewallet'
  final String subtitle;

  const DonationPaymentChannelOption({
    required this.code,
    required this.label,
    required this.shortLabel,
    required this.category,
    required this.subtitle,
  });
}

const List<DonationPaymentChannelOption> donationPaymentChannels = [
  DonationPaymentChannelOption(
    code: 'bca',
    label: 'BCA Virtual Account',
    shortLabel: 'BCA VA',
    category: 'va',
    subtitle: 'Transfer via m-BCA, KlikBCA, atau ATM BCA',
  ),
  DonationPaymentChannelOption(
    code: 'bni',
    label: 'BNI Virtual Account',
    shortLabel: 'BNI VA',
    category: 'va',
    subtitle: 'Transfer via BNI Mobile Banking atau ATM BNI',
  ),
  DonationPaymentChannelOption(
    code: 'bri',
    label: 'BRI Virtual Account (BRIVA)',
    shortLabel: 'BRI VA',
    category: 'va',
    subtitle: 'Transfer via BRImo atau ATM BRI',
  ),
  DonationPaymentChannelOption(
    code: 'mandiri',
    label: 'Mandiri Bill Payment',
    shortLabel: 'Mandiri VA',
    category: 'va',
    subtitle: 'Bayar via Livin by Mandiri atau ATM Mandiri',
  ),
  DonationPaymentChannelOption(
    code: 'permata',
    label: 'Permata Virtual Account',
    shortLabel: 'Permata VA',
    category: 'va',
    subtitle: 'Transfer via PermataMobile X atau jaringan ATM Bersama',
  ),
  DonationPaymentChannelOption(
    code: 'cimb',
    label: 'CIMB Niaga Virtual Account',
    shortLabel: 'CIMB VA',
    category: 'va',
    subtitle: 'Transfer via OCTO Mobile atau ATM CIMB Niaga',
  ),
  DonationPaymentChannelOption(
    code: 'qris',
    label: 'QRIS (DANA / OVO / LinkAja / m-Banking)',
    shortLabel: 'QRIS',
    category: 'ewallet',
    subtitle: 'Scan QR dari e-wallet atau aplikasi bank mana saja',
  ),
  DonationPaymentChannelOption(
    code: 'gopay',
    label: 'GoPay',
    shortLabel: 'GoPay',
    category: 'ewallet',
    subtitle: 'Bayar langsung lewat aplikasi Gojek / QR GoPay',
  ),
  DonationPaymentChannelOption(
    code: 'shopeepay',
    label: 'ShopeePay',
    shortLabel: 'ShopeePay',
    category: 'ewallet',
    subtitle: 'Bayar langsung lewat aplikasi Shopee / ShopeePay',
  ),
];

String buildDonationPageLink({
  required String storeId,
  String? storeName,
  String? contentId,
  String? contentTitle,
}) {
  final params = <String, String>{
    'storeId': storeId.trim(),
  };
  if (contentId != null && contentId.trim().isNotEmpty) {
    params['contentId'] = contentId.trim();
  }
  return Uri(
    scheme: 'umk',
    host: 'donations',
    path: '/pay',
    queryParameters: params,
  ).toString();
}

String buildInternalDonationRoute({
  required String storeId,
  String? storeName,
  String? contentId,
  String? contentTitle,
  String? donationId,
  bool editMode = false,
}) {
  final params = <String, String>{};
  if (storeId.trim().isNotEmpty) {
    params['storeId'] = storeId.trim();
  }
  if (storeName != null && storeName.trim().isNotEmpty) {
    params['storeName'] = storeName.trim();
  }
  if (contentId != null && contentId.trim().isNotEmpty) {
    params['contentId'] = contentId.trim();
  }
  if (contentTitle != null && contentTitle.trim().isNotEmpty) {
    params['contentTitle'] = contentTitle.trim();
  }
  if (donationId != null && donationId.trim().isNotEmpty) {
    params['donationId'] = donationId.trim();
  }
  if (editMode) {
    params['edit'] = '1';
  }
  return Uri(path: '/donations/pay', queryParameters: params).toString();
}

String? extractInternalDonationRoute(String? rawTextOrUrl) {
  if (rawTextOrUrl == null || rawTextOrUrl.trim().isEmpty) return null;

  final match = RegExp(
    r'(?:umk://donations/pay(?:\?[^\s]+)?|/donations/pay(?:\?[^\s]+)?)',
    caseSensitive: false,
  ).firstMatch(rawTextOrUrl);

  if (match == null) return null;

  var matched = match.group(0)!.replaceAll(RegExp(r'[.,;:!?\)\]]+$'), '');
  if (matched.toLowerCase().startsWith('umk://')) {
    final uri = Uri.tryParse(matched);
    if (uri == null) return null;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return '/donations/pay$query';
  }

  return matched;
}

class BuyerDonationRecord {
  final String id;
  final String? userId;
  final String storeId;
  final String? storeName;
  final String? contentId;
  final String? contentTitle;
  final String? contentType;
  final String? donationNumber;
  final int amount;
  final String donorName;
  final String? donorPhone;
  final String? donorEmail;
  final String? note;
  final String status;
  final String? paymentType;
  final String? paymentChannel;
  final String? vaNumber;
  final String? billerCode;
  final String? qrUrl;
  final String? deeplinkUrl;
  final DateTime? expiredAt;
  final DateTime? paidAt;
  final DateTime? distributedAt;
  final int? distributedAmount;
  final DateTime createdAt;

  bool get canModify => status != 'distributed';

  bool get canChangePaymentOrCancel =>
      status == 'pending' || status == 'expired' || status == 'failed';

  bool get isPendingActive =>
      status == 'pending' &&
      (expiredAt == null || expiredAt!.isAfter(DateTime.now()));

  bool get isSettledOrDistributed => status == 'paid' || status == 'distributed';

  String get paymentChannelLabel {
    final channel = paymentChannel?.toLowerCase();
    for (final opt in donationPaymentChannels) {
      if (opt.code == channel) return opt.label;
    }
    if (channel != null && channel.isNotEmpty) {
      return channel.toUpperCase();
    }
    return 'Virtual Account / QRIS';
  }

  String get paymentChannelShortLabel {
    final channel = paymentChannel?.toLowerCase();
    for (final opt in donationPaymentChannels) {
      if (opt.code == channel) return opt.shortLabel;
    }
    if (channel != null && channel.isNotEmpty) {
      return channel.toUpperCase();
    }
    return 'VA/QRIS';
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return isPendingActive ? 'Menunggu Pembayaran' : 'Kadaluarsa';
      case 'paid':
        return 'Lunas / Siap Disalurkan';
      case 'distributed':
        return 'Telah Disalurkan';
      case 'expired':
        return 'Kadaluarsa';
      case 'failed':
        return 'Gagal';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  BuyerDonationRecord({
    required this.id,
    this.userId,
    required this.storeId,
    this.storeName,
    this.contentId,
    this.contentTitle,
    this.contentType,
    this.donationNumber,
    required this.amount,
    required this.donorName,
    this.donorPhone,
    this.donorEmail,
    this.note,
    required this.status,
    this.paymentType,
    this.paymentChannel,
    this.vaNumber,
    this.billerCode,
    this.qrUrl,
    this.deeplinkUrl,
    this.expiredAt,
    this.paidAt,
    this.distributedAt,
    this.distributedAmount,
    required this.createdAt,
  });

  factory BuyerDonationRecord.fromMap(Map<String, dynamic> map) {
    final store = map['stores'] as Map<String, dynamic>?;
    final content = map['store_contents'] as Map<String, dynamic>?;
    return BuyerDonationRecord(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String?,
      storeId: map['store_id'] as String? ?? '',
      storeName: store?['name'] as String?,
      contentId: map['content_id'] as String?,
      contentTitle: content?['title'] as String?,
      contentType: content?['content_type'] as String?,
      donationNumber: map['donation_number'] as String?,
      amount: (map['amount'] as num?)?.round() ?? 0,
      donorName: map['donor_name'] as String? ?? 'Hamba Allah (Anonim)',
      donorPhone: map['donor_phone'] as String?,
      donorEmail: map['donor_email'] as String?,
      note: map['note'] as String?,
      status: map['status'] as String? ?? 'pending',
      paymentType: map['payment_type'] as String?,
      paymentChannel: map['payment_channel'] as String?,
      vaNumber: map['va_number'] as String?,
      billerCode: map['biller_code'] as String?,
      qrUrl: map['qr_url'] as String?,
      deeplinkUrl: map['deeplink_url'] as String?,
      expiredAt: map['expired_at'] != null
          ? DateTime.tryParse(map['expired_at'] as String)
          : null,
      paidAt: map['paid_at'] != null
          ? DateTime.tryParse(map['paid_at'] as String)
          : null,
      distributedAt: map['distributed_at'] != null
          ? DateTime.tryParse(map['distributed_at'] as String)
          : null,
      distributedAmount: (map['distributed_amount'] as num?)?.round(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class BuyerDonationService {
  Future<List<BuyerDonationRecord>> getMyDonations() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('donations')
          .select('''
            *,
            stores (
              name
            ),
            store_contents (
              title,
              content_type
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (e) => BuyerDonationRecord.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (_) {
      final fallback = await supabase
          .from('donations')
          .select('''
            *,
            stores (
              name
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (fallback as List<dynamic>)
          .map(
            (e) => BuyerDonationRecord.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }
  }

  Future<BuyerDonationRecord?> getDonationById(String donationId) async {
    final response = await supabase
        .from('donations')
        .select('''
          *,
          stores (
            name
          ),
          store_contents (
            title,
            content_type
          )
        ''')
        .eq('id', donationId)
        .maybeSingle();

    if (response == null) return null;
    return BuyerDonationRecord.fromMap(Map<String, dynamic>.from(response));
  }

  Future<String?> getCurrentUserFullName() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final userRow = await supabase
        .from('users')
        .select('full_name')
        .eq('id', userId)
        .maybeSingle();

    final name = userRow?['full_name'] as String?;
    return (name != null && name.trim().isNotEmpty) ? name.trim() : null;
  }

  Future<Map<String, String?>> resolveStoreAndContentLabels({
    required String storeId,
    String? contentId,
  }) async {
    String? storeName;
    String? contentTitle;

    if (storeId.trim().isNotEmpty) {
      final storeRow = await supabase
          .from('stores')
          .select('name')
          .eq('id', storeId)
          .maybeSingle();
      storeName = storeRow?['name'] as String?;
    }

    if (contentId != null && contentId.trim().isNotEmpty) {
      final contentRow = await supabase
          .from('store_contents')
          .select('title')
          .eq('id', contentId)
          .maybeSingle();
      contentTitle = contentRow?['title'] as String?;
    }

    return {'storeName': storeName, 'contentTitle': contentTitle};
  }

  Future<Map<String, dynamic>> generateDonationPayment({
    String? donationId,
    required String storeId,
    String? contentId,
    required int amount,
    required String donorName,
    String? note,
    required String paymentChannel,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Silakan login terlebih dahulu untuk berdonasi.');
    }

    final payload = <String, dynamic>{
      'store_id': storeId,
      'amount': amount,
      'donor_name': donorName.trim().isEmpty
          ? 'Hamba Allah (Anonim)'
          : donorName.trim(),
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'payment_channel': paymentChannel,
    };

    if (donationId != null && donationId.isNotEmpty) {
      payload['donation_id'] = donationId;
    }
    if (contentId != null && contentId.isNotEmpty) {
      payload['content_id'] = contentId;
    }

    final response = await supabase.functions.invoke(
      'donation-checkout',
      body: payload,
    );

    if (response.status != 200) {
      final errData = response.data;
      final message = errData is Map
          ? (errData['error'] ?? 'Gagal membuat tagihan VA/QRIS donasi')
          : 'Gagal membuat tagihan VA/QRIS donasi';
      throw Exception(message);
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> checkDonationPaymentStatus(
    String donationId,
  ) async {
    final response = await supabase.functions.invoke(
      'check-payment-status',
      body: {'donation_id': donationId},
    );

    if (response.status != 200) {
      final errData = response.data;
      final message = errData is Map
          ? (errData['error'] ?? 'Gagal memeriksa status pembayaran donasi')
          : 'Gagal memeriksa status pembayaran donasi';
      throw Exception(message);
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> updateDonorInfo({
    required String donationId,
    required String donorName,
    String? note,
  }) async {
    await supabase
        .from('donations')
        .update({
          'donor_name': donorName.trim().isEmpty
              ? 'Hamba Allah (Anonim)'
              : donorName.trim(),
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', donationId);
  }

  Future<void> deleteDonation(String donationId) async {
    await supabase.from('donations').delete().eq('id', donationId);
  }
}

final buyerDonationServiceProvider = Provider<BuyerDonationService>((ref) {
  return BuyerDonationService();
});

final myDonationsProvider =
    FutureProvider.autoDispose<List<BuyerDonationRecord>>((ref) async {
      final service = ref.watch(buyerDonationServiceProvider);
      return service.getMyDonations();
    });

Future<bool?> showBuyerDonationDialog(
  BuildContext context,
  WidgetRef ref, {
  required String storeId,
  required String storeName,
  String? contentId,
  String? contentTitle,
  BuyerDonationRecord? existingDonation,
  bool editMode = false,
}) async {
  final route = buildInternalDonationRoute(
    storeId: existingDonation?.storeId ?? storeId,
    storeName: existingDonation?.storeName ?? storeName,
    contentId: existingDonation?.contentId ?? contentId,
    contentTitle: existingDonation?.contentTitle ?? contentTitle,
    donationId: existingDonation?.id,
    editMode: editMode,
  );
  final result = await context.push<bool>(route, extra: existingDonation);
  return result;
}
