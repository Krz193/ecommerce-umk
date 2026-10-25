class StoreVoucherModel {
  final String id;
  final String storeId;
  final String code;
  final String title;
  final String scope; // 'order' or 'product'
  final List<String> applicableProductIds;
  final String discountType; // 'nominal', 'percentage', 'fixed_price'
  final double discountValue;
  final double minPurchase;
  final double? maxDiscount;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? usageLimit;
  final int usedCount;
  final bool isActive;

  StoreVoucherModel({
    required this.id,
    required this.storeId,
    required this.code,
    required this.title,
    this.scope = 'order',
    this.applicableProductIds = const [],
    required this.discountType,
    required this.discountValue,
    this.minPurchase = 0,
    this.maxDiscount,
    this.startDate,
    this.endDate,
    this.usageLimit = 1,
    this.usedCount = 0,
    this.isActive = true,
  });

  bool get isSingleUse => usageLimit == 1;
  bool get isProductSpecific => scope == 'product' && applicableProductIds.isNotEmpty;

  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  bool get isQuotaExhausted {
    if (usageLimit == null) return false;
    return usedCount >= usageLimit!;
  }

  bool get canBeUsed => isActive && !isExpired && !isQuotaExhausted;

  String get discountTypeLabel {
    switch (discountType) {
      case 'nominal':
        return 'Potongan Nominal';
      case 'percentage':
        return 'Potongan Persen';
      case 'fixed_price':
        return isProductSpecific ? 'Harga Khusus Baru / Item' : 'Harga Khusus Borongan';
      default:
        return discountType;
    }
  }

  /// Menghitung diskon baik per order maupun per produk spesifik (jika ada multiple item di keranjang)
  int calculateDiscountForItems(List<Map<String, dynamic>> items, int subtotal) {
    if (subtotal < minPurchase) return 0;

    double totalDiscount = 0;

    if (isProductSpecific) {
      int matchedCount = 0;
      for (final item in items) {
        final prodId = (item['product_id'] ?? item['id'])?.toString();
        final price = (item['price'] as num?)?.toDouble() ?? 0;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;

        if (prodId != null && applicableProductIds.contains(prodId)) {
          matchedCount++;
          if (discountType == 'nominal') {
            final itemDiscount = (discountValue > price ? price : discountValue) * qty;
            totalDiscount += itemDiscount;
          } else if (discountType == 'percentage') {
            final itemDiscount = ((price * discountValue) / 100.0) * qty;
            totalDiscount += itemDiscount;
          } else if (discountType == 'fixed_price') {
            if (price > discountValue) {
              totalDiscount += (price - discountValue) * qty;
            }
          }
        }
      }

      if (matchedCount == 0) return 0;

      if (discountType == 'percentage' && maxDiscount != null && maxDiscount! > 0) {
        if (totalDiscount > maxDiscount!) totalDiscount = maxDiscount!;
      }
    } else {
      // Per order subtotal
      if (discountType == 'nominal') {
        totalDiscount = discountValue;
        if (totalDiscount > subtotal) totalDiscount = subtotal.toDouble();
      } else if (discountType == 'percentage') {
        totalDiscount = (subtotal * discountValue) / 100.0;
        if (maxDiscount != null && maxDiscount! > 0 && totalDiscount > maxDiscount!) {
          totalDiscount = maxDiscount!;
        }
        if (totalDiscount > subtotal) totalDiscount = subtotal.toDouble();
      } else if (discountType == 'fixed_price') {
        if (subtotal > discountValue) {
          totalDiscount = (subtotal - discountValue);
        } else {
          totalDiscount = 0;
        }
      }
    }

    return totalDiscount.round();
  }

  factory StoreVoucherModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedProductIds = [];
    final rawProds = map['applicable_product_ids'];
    if (rawProds is List) {
      parsedProductIds = rawProds.map((e) => e.toString()).toList();
    }

    return StoreVoucherModel(
      id: map['id']?.toString() ?? '',
      storeId: map['store_id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      scope: map['scope']?.toString() ?? 'order',
      applicableProductIds: parsedProductIds,
      discountType: map['discount_type']?.toString() ?? 'nominal',
      discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0.0,
      minPurchase: (map['min_purchase'] as num?)?.toDouble() ?? 0.0,
      maxDiscount: (map['max_discount'] as num?)?.toDouble(),
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'].toString())
          : null,
      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'].toString())
          : null,
      usageLimit: (map['usage_limit'] as num?)?.toInt(),
      usedCount: (map['used_count'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'store_id': storeId,
      'code': code.toUpperCase().trim(),
      'title': title.trim(),
      'scope': scope,
      'applicable_product_ids': applicableProductIds.isNotEmpty ? applicableProductIds : null,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_purchase': minPurchase,
      'max_discount': maxDiscount,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'usage_limit': usageLimit,
      'used_count': usedCount,
      'is_active': isActive,
    };
  }
}
