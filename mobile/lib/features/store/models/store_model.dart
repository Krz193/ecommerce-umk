class LocalShippingRateTier {
  final double minKm;
  final double maxKm;
  final int price;

  const LocalShippingRateTier({
    required this.minKm,
    required this.maxKm,
    required this.price,
  });

  factory LocalShippingRateTier.fromMap(Map<String, dynamic> map) {
    return LocalShippingRateTier(
      minKm: (map['min_km'] as num?)?.toDouble() ?? 0.0,
      maxKm: (map['max_km'] as num?)?.toDouble() ?? 0.0,
      price: (map['price'] as num?)?.round() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'min_km': minKm,
      'max_km': maxKm,
      'price': price,
    };
  }

  /// Returns null when valid, or an Indonesian validation error message.
  static String? validateTiers(List<LocalShippingRateTier> tiers) {
    for (var i = 0; i < tiers.length; i++) {
      final t = tiers[i];
      if (t.minKm < 0) {
        return 'Jarak minimal pada baris #${i + 1} tidak boleh negatif.';
      }
      if (t.maxKm <= t.minKm) {
        return 'Jarak maksimal harus lebih besar dari jarak minimal pada baris #${i + 1}.';
      }
      if (t.price < 0) {
        return 'Ongkos kirim pada baris #${i + 1} tidak boleh negatif.';
      }
    }

    final sorted = List<LocalShippingRateTier>.from(tiers)
      ..sort((a, b) => a.minKm.compareTo(b.minKm));

    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].minKm < sorted[i - 1].maxKm) {
        return 'Rentang jarak tumpang tindih antara ${sorted[i - 1].minKm}-${sorted[i - 1].maxKm} km dan ${sorted[i].minKm}-${sorted[i].maxKm} km.';
      }
    }

    return null;
  }
}

class StoreModel {
  final String id;
  final String ownerId;
  final String name;
  final String slug;
  final String? description;
  final String? phone;
  final String? address;
  final String? province;
  final String? city;
  final String? district;
  final String? postalCode;
  final String? notes;
  final String? biteshipAreaId;
  final double? latitude;
  final double? longitude;
  final bool localOjekEnabled;
  final List<LocalShippingRateTier> localOjekRates;
  final bool localEkspedisiEnabled;
  final List<LocalShippingRateTier> localEkspedisiRates;
  final String status;

  StoreModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slug,
    required this.description,
    required this.phone,
    required this.address,
    this.province,
    this.city,
    this.district,
    this.postalCode,
    this.notes,
    this.biteshipAreaId,
    this.latitude,
    this.longitude,
    this.localOjekEnabled = false,
    this.localOjekRates = const [],
    this.localEkspedisiEnabled = false,
    this.localEkspedisiRates = const [],
    required this.status,
  });

  bool get hasValidCoordinates =>
      latitude != null &&
      longitude != null &&
      !(latitude == 0 && longitude == 0);

  static List<LocalShippingRateTier> _parseRateTiers(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => LocalShippingRateTier.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  factory StoreModel.fromMap(Map<String, dynamic> map) {
    return StoreModel(
      id: map['id'],
      ownerId: map['owner_id'],
      name: map['name'],
      slug: map['slug'],
      description: map['description'],
      phone: map['phone'],
      address: map['address'],
      province: map['province'],
      city: map['city'],
      district: map['district'],
      postalCode: map['postal_code'],
      notes: map['notes'],
      biteshipAreaId: map['biteship_area_id'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      localOjekEnabled: map['local_ojek_enabled'] == true,
      localOjekRates: _parseRateTiers(map['local_ojek_rates']),
      localEkspedisiEnabled: map['local_ekspedisi_enabled'] == true,
      localEkspedisiRates: _parseRateTiers(map['local_ekspedisi_rates']),
      status: map['status'],
    );
  }
}
