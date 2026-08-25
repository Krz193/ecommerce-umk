class ShippingRateOption {
  final String courierName;
  final String courierCode;
  final String courierServiceName;
  final String courierServiceCode;
  final String serviceType; // 'instant', 'same_day', 'standard', 'express'
  final int price;
  final String durationRange;
  final String durationUnit;
  final String description;

  ShippingRateOption({
    required this.courierName,
    required this.courierCode,
    required this.courierServiceName,
    required this.courierServiceCode,
    required this.serviceType,
    required this.price,
    required this.durationRange,
    required this.durationUnit,
    this.description = '',
  });

  factory ShippingRateOption.fromMap(Map<String, dynamic> map) {
    return ShippingRateOption(
      courierName: map['courier_name'] ?? 'Kurir',
      courierCode: map['courier_code'] ?? 'manual',
      courierServiceName: map['courier_service_name'] ?? 'Reguler',
      courierServiceCode: map['courier_service_code'] ?? 'reg',
      serviceType: map['service_type'] ?? 'standard',
      price: (map['price'] as num?)?.toInt() ?? 0,
      durationRange: map['shipment_duration_range'] ?? '1 - 2',
      durationUnit: map['shipment_duration_unit'] ?? 'days',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courier_name': courierName,
      'courier_code': courierCode,
      'courier_service_name': courierServiceName,
      'courier_service_code': courierServiceCode,
      'service_type': serviceType,
      'price': price,
      'shipment_duration_range': durationRange,
      'shipment_duration_unit': durationUnit,
      'description': description,
    };
  }

  bool get isInstant => serviceType == 'instant' || serviceType == 'same_day';

  String get durationLabel {
    final unitLabel = durationUnit == 'hours' ? 'Jam' : 'Hari';
    return '$durationRange $unitLabel';
  }

  String get displayName => '$courierName - $courierServiceName';
}
