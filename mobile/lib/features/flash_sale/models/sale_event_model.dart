import 'package:mobile/features/product/models/product_model.dart';

class SaleEventModel {
  final String id;
  final String? storeId;
  final String? storeName;
  final String title;
  final String slug;
  final String? description;
  final String? bannerUrl;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;
  final List<SaleEventItemModel> items;

  const SaleEventModel({
    required this.id,
    this.storeId,
    this.storeName,
    required this.title,
    required this.slug,
    this.description,
    this.bannerUrl,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    this.items = const [],
  });

  bool get isPlatformEvent => storeId == null || storeId!.isEmpty;

  bool get isOngoing {
    final now = DateTime.now().toUtc();
    return isActive &&
        !now.isBefore(startTime.toUtc()) &&
        !now.isAfter(endTime.toUtc());
  }

  bool get isUpcoming {
    final now = DateTime.now().toUtc();
    return isActive && now.isBefore(startTime.toUtc());
  }

  bool get isEnded => DateTime.now().toUtc().isAfter(endTime.toUtc());

  Duration get countdownRemaining {
    final now = DateTime.now().toUtc();
    final target = isUpcoming ? startTime.toUtc() : endTime.toUtc();
    final diff = target.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  factory SaleEventModel.fromJson(Map<String, dynamic> json) {
    final store = json['store'] ?? json['stores'];
    final rawItems = json['sale_event_items'];

    return SaleEventModel(
      id: json['id'].toString(),
      storeId: json['store_id']?.toString(),
      storeName: store is Map ? store['name']?.toString() : null,
      title: (json['title'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      description: json['description']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      startTime: DateTime.parse(json['start_time'].toString()).toLocal(),
      endTime: DateTime.parse(json['end_time'].toString()).toLocal(),
      isActive: json['is_active'] == true,
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(SaleEventItemModel.fromJson)
                .toList()
          : const [],
    );
  }
}

class SaleEventItemModel {
  final String id;
  final String saleEventId;
  final String productId;
  final String storeId;
  final String discountType;
  final double discountValue;
  final int salePrice;
  final int? saleQuota;
  final int soldCount;
  final int? maxQtyPerUser;
  final bool isActive;
  final ProductModel? product;

  const SaleEventItemModel({
    required this.id,
    required this.saleEventId,
    required this.productId,
    required this.storeId,
    required this.discountType,
    required this.discountValue,
    required this.salePrice,
    this.saleQuota,
    this.soldCount = 0,
    this.maxQtyPerUser,
    this.isActive = true,
    this.product,
  });

  int? get remainingQuota {
    if (saleQuota == null) return null;
    return (saleQuota! - soldCount).clamp(0, saleQuota!);
  }

  bool get isQuotaExhausted => saleQuota != null && soldCount >= saleQuota!;

  double get soldRatio {
    if (saleQuota == null || saleQuota! <= 0) return 0;
    return (soldCount / saleQuota!).clamp(0.0, 1.0);
  }

  int effectiveDiscountPercent(int regularPrice) {
    if (regularPrice <= 0 || salePrice >= regularPrice) return 0;
    return (((regularPrice - salePrice) / regularPrice) * 100).round();
  }

  factory SaleEventItemModel.fromJson(Map<String, dynamic> json) {
    final rawProduct = json['product'] ?? json['products'];
    return SaleEventItemModel(
      id: json['id'].toString(),
      saleEventId: json['sale_event_id'].toString(),
      productId: json['product_id'].toString(),
      storeId: json['store_id'].toString(),
      discountType: (json['discount_type'] ?? 'percentage').toString(),
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0,
      salePrice: (json['sale_price'] as num?)?.round() ?? 0,
      saleQuota: (json['sale_quota'] as num?)?.toInt(),
      soldCount: (json['sold_count'] as num?)?.toInt() ?? 0,
      maxQtyPerUser: (json['max_qty_per_user'] as num?)?.toInt(),
      isActive: json['is_active'] != false,
      product: rawProduct is Map<String, dynamic>
          ? ProductModel.fromJson(rawProduct)
          : null,
    );
  }
}

class FlashSalePriceSplit {
  final int saleQty;
  final int regularQty;
  final int salePrice;
  final int regularPrice;
  final int totalSubtotal;

  const FlashSalePriceSplit({
    required this.saleQty,
    required this.regularQty,
    required this.salePrice,
    required this.regularPrice,
    required this.totalSubtotal,
  });

  bool get hasFlashSale => saleQty > 0;
  bool get isSplit => saleQty > 0 && regularQty > 0;
}

class ProductFlashSaleInfo {
  final String productId;
  final String saleEventId;
  final String saleEventItemId;
  final String eventTitle;
  final DateTime startTime;
  final DateTime endTime;
  final String discountType;
  final double discountValue;
  final int salePrice;
  final int regularPrice;
  final int? saleQuota;
  final int soldCount;
  final int? maxQtyPerUser;
  final int? remainingSaleQuota;
  final int userPurchasedQty;
  final int? eligibleQty;

  const ProductFlashSaleInfo({
    required this.productId,
    required this.saleEventId,
    required this.saleEventItemId,
    required this.eventTitle,
    required this.startTime,
    required this.endTime,
    required this.discountType,
    required this.discountValue,
    required this.salePrice,
    required this.regularPrice,
    this.saleQuota,
    required this.soldCount,
    this.maxQtyPerUser,
    this.remainingSaleQuota,
    required this.userPurchasedQty,
    this.eligibleQty,
  });

  int get effectiveDiscountPercent {
    if (regularPrice <= 0 || salePrice >= regularPrice) return 0;
    return (((regularPrice - salePrice) / regularPrice) * 100).round();
  }

  Duration get remainingDuration {
    final diff = endTime.toUtc().difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Splits [cartQty] between Flash Sale price (up to eligible quota) and regular price.
  FlashSalePriceSplit splitForQuantity(
    int cartQty, {
    int? fallbackRegularPrice,
  }) {
    final normalPrice = regularPrice > 0
        ? regularPrice
        : (fallbackRegularPrice ?? salePrice);

    if (cartQty <= 0 || salePrice >= normalPrice) {
      return FlashSalePriceSplit(
        saleQty: 0,
        regularQty: cartQty,
        salePrice: salePrice,
        regularPrice: normalPrice,
        totalSubtotal: normalPrice * cartQty,
      );
    }

    final maxEligible = eligibleQty == null
        ? cartQty
        : eligibleQty!.clamp(0, cartQty);
    final regularQty = cartQty - maxEligible;

    return FlashSalePriceSplit(
      saleQty: maxEligible,
      regularQty: regularQty,
      salePrice: salePrice,
      regularPrice: normalPrice,
      totalSubtotal: (maxEligible * salePrice) + (regularQty * normalPrice),
    );
  }

  factory ProductFlashSaleInfo.fromJson(Map<String, dynamic> json) {
    return ProductFlashSaleInfo(
      productId: json['product_id'].toString(),
      saleEventId: json['sale_event_id'].toString(),
      saleEventItemId: json['sale_event_item_id'].toString(),
      eventTitle: (json['event_title'] ?? 'Flash Sale').toString(),
      startTime: DateTime.parse(json['start_time'].toString()).toLocal(),
      endTime: DateTime.parse(json['end_time'].toString()).toLocal(),
      discountType: (json['discount_type'] ?? 'percentage').toString(),
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0,
      salePrice: (json['sale_price'] as num?)?.round() ?? 0,
      regularPrice: (json['regular_price'] as num?)?.round() ?? 0,
      saleQuota: (json['sale_quota'] as num?)?.toInt(),
      soldCount: (json['sold_count'] as num?)?.toInt() ?? 0,
      maxQtyPerUser: (json['max_qty_per_user'] as num?)?.toInt(),
      remainingSaleQuota: (json['remaining_sale_quota'] as num?)?.toInt(),
      userPurchasedQty: (json['user_purchased_qty'] as num?)?.toInt() ?? 0,
      eligibleQty: (json['eligible_qty'] as num?)?.toInt(),
    );
  }
}
