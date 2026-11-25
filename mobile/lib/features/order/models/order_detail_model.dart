import 'dart:math' as math;

import 'package:mobile/features/order/models/order_payment_model.dart';

class OrderItemModel {
  final String id;
  final String productId;
  final String productName;
  final int productPrice;
  final int quantity;
  final int subtotal;
  final String? productThumbnail;

  OrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.subtotal,
    this.productThumbnail,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'],
      productId: json['product_id'] ?? '',
      productName: json['product_name'],
      productPrice: (json['product_price'] as num).toInt(),
      quantity: json['quantity'],
      subtotal: (json['subtotal'] as num).toInt(),
      productThumbnail: json['product_thumbnail'],
    );
  }
}

class ShipmentCheckpointPoint {
  final int index;
  final String status;
  final String title;
  final String note;
  final DateTime? timestamp;
  final String? role;
  final String? driverName;
  final double latitude;
  final double longitude;
  final bool isEstimatedCoordinate;

  const ShipmentCheckpointPoint({
    required this.index,
    required this.status,
    required this.title,
    required this.note,
    this.timestamp,
    this.role,
    this.driverName,
    required this.latitude,
    required this.longitude,
    required this.isEstimatedCoordinate,
  });
}

class OrderDetailModel {
  final String id;
  final String? userId;
  final String? storeId;
  final String? storeName;
  final String? storeSlug;
  final String? storePhone;
  final String? storeAddress;
  final String? storeCity;
  final String? storePostalCode;
  final String? storeNotes;
  final double? storeLatitude;
  final double? storeLongitude;
  final String? originContactName;
  final String? originPhone;
  final String? originAddress;
  final String? originCity;
  final String? originPostalCode;
  final String? originNotes;
  final String? originAreaId;
  final double? originLatitude;
  final double? originLongitude;
  final String orderNumber;
  final String status;
  final int totalAmount;
  final int subtotal;
  final int shippingCost;
  final String paymentStatus;
  final String shippingName;
  final String shippingPhone;
  final String shippingAddress;
  final String? shippingCity;
  final String? shippingPostalCode;
  final String? shippingNotes;
  final double? shippingLatitude;
  final double? shippingLongitude;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? completedAt;
  final String? shippingProvider;
  final String? courierName;
  final String? courierCode;
  final String? courierServiceCode;
  final String? courierServiceType;
  final String? biteshipOrderId;
  final String? trackingNumber;
  final String? waybillId;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverVehiclePlate;
  final double? driverLatitude;
  final double? driverLongitude;
  final DateTime? driverLastUpdated;
  final String? trackingStatus;
  final String? trackingUrl;
  final List<Map<String, dynamic>> trackingHistory;
  final List<Map<String, dynamic>> driverMessages;
  final List<OrderItemModel> items;
  final OrderPaymentModel? payment;

  OrderDetailModel({
    required this.id,
    this.userId,
    this.storeId,
    this.storeName,
    this.storeSlug,
    this.storePhone,
    this.storeAddress,
    this.storeCity,
    this.storePostalCode,
    this.storeNotes,
    this.storeLatitude,
    this.storeLongitude,
    this.originContactName,
    this.originPhone,
    this.originAddress,
    this.originCity,
    this.originPostalCode,
    this.originNotes,
    this.originAreaId,
    this.originLatitude,
    this.originLongitude,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    this.subtotal = 0,
    this.shippingCost = 0,
    required this.paymentStatus,
    required this.shippingName,
    required this.shippingPhone,
    required this.shippingAddress,
    this.shippingCity,
    this.shippingPostalCode,
    this.shippingNotes,
    this.shippingLatitude,
    this.shippingLongitude,
    required this.createdAt,
    required this.paidAt,
    required this.shippedAt,
    required this.completedAt,
    required this.shippingProvider,
    this.courierName,
    this.courierCode,
    this.courierServiceCode,
    this.courierServiceType,
    this.biteshipOrderId,
    required this.trackingNumber,
    this.waybillId,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverVehiclePlate,
    this.driverLatitude,
    this.driverLongitude,
    this.driverLastUpdated,
    this.trackingStatus,
    this.trackingUrl,
    this.trackingHistory = const [],
    this.driverMessages = const [],
    required this.items,
    required this.payment,
  });

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    final storeMap = json['store'] is Map<String, dynamic>
        ? json['store'] as Map<String, dynamic>
        : (json['stores'] is Map<String, dynamic>
              ? json['stores'] as Map<String, dynamic>
              : null);

    final rawHistory = json['tracking_history'];
    final historyList = rawHistory is List
        ? rawHistory
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    final rawMessages = json['driver_messages'];
    final messagesList = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    return OrderDetailModel(
      id: json['id'],
      userId: json['user_id']?.toString(),
      storeId: json['store_id']?.toString() ?? storeMap?['id']?.toString(),
      storeName: storeMap?['name']?.toString(),
      storeSlug: storeMap?['slug']?.toString(),
      storePhone: storeMap?['phone']?.toString(),
      storeAddress: storeMap?['address']?.toString(),
      storeCity: storeMap?['city']?.toString(),
      storePostalCode: storeMap?['postal_code']?.toString(),
      storeNotes: storeMap?['notes']?.toString(),
      storeLatitude: (storeMap?['latitude'] as num?)?.toDouble(),
      storeLongitude: (storeMap?['longitude'] as num?)?.toDouble(),
      originContactName: json['origin_contact_name']?.toString(),
      originPhone: json['origin_phone']?.toString(),
      originAddress: json['origin_address']?.toString(),
      originCity: json['origin_city']?.toString(),
      originPostalCode: json['origin_postal_code']?.toString(),
      originNotes: json['origin_notes']?.toString(),
      originAreaId: json['origin_area_id']?.toString(),
      originLatitude: (json['origin_latitude'] as num?)?.toDouble(),
      originLongitude: (json['origin_longitude'] as num?)?.toDouble(),
      orderNumber: json['order_number'],
      status: json['status'],
      totalAmount: (json['total_amount'] as num).toInt(),
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      shippingCost: (json['shipping_cost'] as num?)?.toInt() ?? 0,
      paymentStatus: json['payment_status'],
      shippingName: json['shipping_name'] ?? '',
      shippingPhone: json['shipping_phone'] ?? '',
      shippingAddress: json['shipping_address'] ?? '',
      shippingCity: json['shipping_city']?.toString(),
      shippingPostalCode: json['shipping_postal_code']?.toString(),
      shippingNotes: json['shipping_notes'],
      shippingLatitude: (json['shipping_latitude'] as num?)?.toDouble(),
      shippingLongitude: (json['shipping_longitude'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      shippedAt: json['shipped_at'] != null
          ? DateTime.parse(json['shipped_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      shippingProvider: json['shipping_provider'],
      courierName: json['courier_name'] ?? json['shipping_provider'],
      courierCode: json['courier_code'],
      courierServiceCode: json['courier_service_code']?.toString(),
      courierServiceType: json['courier_service_type'],
      biteshipOrderId: json['biteship_order_id']?.toString(),
      trackingNumber: json['tracking_number'],
      waybillId: json['waybill_id'] ?? json['tracking_number'],
      driverId: json['driver_id']?.toString(),
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
      driverVehiclePlate: json['driver_vehicle_plate']?.toString(),
      driverLatitude: (json['driver_latitude'] as num?)?.toDouble(),
      driverLongitude: (json['driver_longitude'] as num?)?.toDouble(),
      driverLastUpdated: json['driver_last_updated'] != null
          ? DateTime.tryParse(json['driver_last_updated'].toString())
          : null,
      trackingStatus: json['tracking_status'],
      trackingUrl: json['tracking_url']?.toString(),
      trackingHistory: historyList,
      driverMessages: messagesList,
      items: (json['order_items'] as List? ?? [])
          .map((item) => OrderItemModel.fromJson(item))
          .toList(),
      payment: json['payment'] != null
          ? OrderPaymentModel.fromJson(json['payment'])
          : null,
    );
  }

  String get effectiveOriginName =>
      (originContactName?.trim().isNotEmpty == true
          ? originContactName!.trim()
          : storeName?.trim()) ??
      'Toko UMK';

  String? get effectiveOriginPhone {
    if (originPhone != null && originPhone!.trim().isNotEmpty) {
      return originPhone!.trim();
    }
    if (storePhone != null && storePhone!.trim().isNotEmpty) {
      return storePhone!.trim();
    }
    return null;
  }

  String get effectiveOriginAddress =>
      (originAddress?.trim().isNotEmpty == true
          ? originAddress!.trim()
          : storeAddress?.trim()) ??
      'Alamat toko belum dilengkapi';

  String? get effectiveOriginCity {
    if (originCity != null && originCity!.trim().isNotEmpty) {
      return originCity!.trim();
    }
    if (storeCity != null && storeCity!.trim().isNotEmpty) {
      return storeCity!.trim();
    }
    return null;
  }

  String? get effectiveOriginPostalCode {
    if (originPostalCode != null && originPostalCode!.trim().isNotEmpty) {
      return originPostalCode!.trim();
    }
    if (storePostalCode != null && storePostalCode!.trim().isNotEmpty) {
      return storePostalCode!.trim();
    }
    return null;
  }

  String? get effectiveOriginNotes {
    if (originNotes != null && originNotes!.trim().isNotEmpty) {
      return originNotes!.trim();
    }
    if (storeNotes != null && storeNotes!.trim().isNotEmpty) {
      return storeNotes!.trim();
    }
    return null;
  }

  bool get isInstantCourier =>
      courierServiceType == 'instant' ||
      courierServiceType == 'same_day' ||
      (courierCode?.toLowerCase().contains('gojek') ?? false) ||
      (courierCode?.toLowerCase().contains('grab') ?? false) ||
      (courierCode?.toLowerCase().contains('ojek') ?? false) ||
      (courierName?.toLowerCase().contains('gojek') ?? false) ||
      (courierName?.toLowerCase().contains('ojek') ?? false);

  bool get isLocalPartnerCourier {
    final code = (courierCode ?? '').toLowerCase().trim();
    return code == 'ojek_lokal' ||
        code == 'ojek' ||
        code == 'ekspedisi' ||
        code == 'ekspedisi_lokal' ||
        code == 'kurir_toko' ||
        code == 'manual';
  }

  bool get isBiteshipManaged {
    if (biteshipOrderId != null && biteshipOrderId!.trim().isNotEmpty) {
      return true;
    }
    if (driverId != null && driverId!.trim().isNotEmpty) {
      return false;
    }
    if (isLocalPartnerCourier) return false;
    final code = (courierCode ?? '').toLowerCase().trim();
    return const [
      'gojek',
      'grab',
      'jne',
      'sicepat',
      'jnt',
      'anteraja',
      'paxel',
      'ninja',
      'lion',
      'pos',
      'tiki',
    ].contains(code);
  }

  bool get isLocalPartnerManaged =>
      !isBiteshipManaged &&
      ((driverId != null && driverId!.trim().isNotEmpty) ||
          isLocalPartnerCourier);

  bool get hasRealDriverPhone =>
      driverPhone != null && driverPhone!.trim().isNotEmpty;

  bool get isShipmentClosed {
    final ts = (trackingStatus ?? '').toLowerCase();
    return status == 'completed' ||
        status == 'cancelled' ||
        status == 'delivered' ||
        ts == 'delivered' ||
        ts == 'completed' ||
        ts == 'cancelled' ||
        ts == 'rejected';
  }

  bool get isShipmentActive {
    final ts = (trackingStatus ?? '').toLowerCase();
    return status == 'shipped' ||
        const [
          'allocated',
          'picking_up',
          'picked',
          'dropping_off',
          'on_delivery',
          'in_transit',
        ].contains(ts);
  }

  bool get hasActiveDriverPosition =>
      driverLatitude != null &&
      driverLongitude != null &&
      driverLatitude != 0 &&
      driverLongitude != 0;

  double get effectiveStoreLat => originLatitude ?? storeLatitude ?? -6.303112;
  double get effectiveStoreLng => originLongitude ?? storeLongitude ?? 106.779493;
  double get effectiveDestLat => shippingLatitude ?? -6.244179;
  double get effectiveDestLng => shippingLongitude ?? 106.783529;

  double get gpsProgressFraction {
    if (status == 'completed' || status == 'delivered') return 1.0;
    final st = (trackingStatus ?? '').toLowerCase();
    switch (st) {
      case 'allocated':
        return 0.20;
      case 'picking_up':
        return 0.35;
      case 'picked':
        return 0.50;
      case 'dropping_off':
      case 'on_delivery':
      case 'in_transit':
        return 0.78;
      case 'delivered':
        return 1.0;
      default:
        return status == 'shipped' ? 0.65 : 0.10;
    }
  }

  double get effectiveDriverLat {
    if (driverLatitude != null) return driverLatitude!;
    final t = gpsProgressFraction;
    return effectiveStoreLat + (effectiveDestLat - effectiveStoreLat) * t;
  }

  double get effectiveDriverLng {
    if (driverLongitude != null) return driverLongitude!;
    final t = gpsProgressFraction;
    return effectiveStoreLng + (effectiveDestLng - effectiveStoreLng) * t;
  }

  double get estimatedDistanceKm {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(effectiveDestLat - effectiveStoreLat);
    final dLng = _degToRad(effectiveDestLng - effectiveStoreLng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(effectiveStoreLat)) *
            math.cos(_degToRad(effectiveDestLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  List<ShipmentCheckpointPoint> get resolvedCheckpoints {
    final source = <Map<String, dynamic>>[...trackingHistory];
    if (source.isEmpty && (status == 'shipped' || status == 'completed')) {
      source.add({
        'status': trackingStatus ?? 'on_delivery',
        'checkpoint_name': 'Pengiriman ${courierName ?? shippingProvider ?? "Ekspedisi"}',
        'note': 'Paket sedang dalam perjalanan menuju alamat tujuan.',
        'timestamp': (shippedAt ?? createdAt).toIso8601String(),
      });
    }

    final total = source.length;
    final points = <ShipmentCheckpointPoint>[];

    for (var i = 0; i < total; i++) {
      final raw = source[i];
      final st = (raw['status'] ?? 'in_transit').toString();
      final checkpointName = raw['checkpoint_name']?.toString().trim();
      final note = raw['note']?.toString().trim() ?? '';
      final tsRaw = raw['timestamp']?.toString();
      final parsedTs = tsRaw != null ? DateTime.tryParse(tsRaw) : null;
      final explicitLat = (raw['latitude'] as num?)?.toDouble();
      final explicitLng = (raw['longitude'] as num?)?.toDouble();
      final hasExplicitCoord =
          explicitLat != null &&
          explicitLng != null &&
          explicitLat != 0 &&
          explicitLng != 0;

      late final double lat;
      late final double lng;

      if (hasExplicitCoord) {
        lat = explicitLat;
        lng = explicitLng;
      } else {
        final t = _checkpointFractionForIndex(st, i, total);
        lat = effectiveStoreLat + (effectiveDestLat - effectiveStoreLat) * t;
        lng = effectiveStoreLng + (effectiveDestLng - effectiveStoreLng) * t;
      }

      points.add(
        ShipmentCheckpointPoint(
          index: i + 1,
          status: st,
          title: (checkpointName != null && checkpointName.isNotEmpty)
              ? checkpointName
              : _defaultCheckpointLabel(st, i + 1),
          note: note.isNotEmpty ? note : _defaultCheckpointNote(st),
          timestamp: parsedTs,
          role: raw['role']?.toString(),
          driverName: raw['driver_name']?.toString(),
          latitude: lat,
          longitude: lng,
          isEstimatedCoordinate: !hasExplicitCoord,
        ),
      );
    }

    return points;
  }

  double _checkpointFractionForIndex(String st, int idx, int total) {
    final lower = st.toLowerCase();
    if (lower == 'delivered' || lower == 'completed') return 1.0;
    if (lower == 'allocated' || lower == 'confirmed') return 0.14;
    if (lower == 'picking_up') return 0.22;
    if (lower == 'picked') return 0.36;
    if (lower == 'on_delivery') return 0.86;
    if (total <= 1) return 0.50;
    return (0.20 + ((idx + 1) / (total + 1)) * 0.70).clamp(0.15, 0.92);
  }

  String _defaultCheckpointLabel(String st, int number) {
    switch (st.toLowerCase()) {
      case 'allocated':
      case 'confirmed':
        return 'Titik #$number • Order Terkonfirmasi';
      case 'picking_up':
        return 'Titik #$number • Penjemputan ke Toko';
      case 'picked':
        return 'Titik #$number • Paket Masuk Hub Asal';
      case 'dropping_off':
      case 'in_transit':
        return 'Titik #$number • Transit Hub / Sortir';
      case 'on_delivery':
        return 'Titik #$number • Kurir Menuju Penerima';
      case 'delivered':
      case 'completed':
        return 'Titik #$number • Paket Tiba di Tujuan';
      case 'cancelled':
      case 'cancelled_by_courier':
        return 'Titik #$number • Pengiriman Dibatalkan';
      default:
        return 'Titik #$number • ${st.toUpperCase()}';
    }
  }

  String _defaultCheckpointNote(String st) {
    switch (st.toLowerCase()) {
      case 'allocated':
        return 'Kurir telah dialokasikan oleh sistem ekspedisi.';
      case 'picking_up':
        return 'Kurir sedang menuju lokasi toko pengirim.';
      case 'picked':
        return 'Paket telah dijemput dan masuk pusat sortir awal.';
      case 'dropping_off':
      case 'in_transit':
        return 'Paket sedang dalam perjalanan antar hub ekspedisi.';
      case 'on_delivery':
        return 'Kurir sedang mengantarkan paket ke alamat penerima.';
      case 'delivered':
      case 'completed':
        return 'Paket telah diterima di alamat tujuan.';
      default:
        return 'Pembaruan status pengiriman.';
    }
  }
}
