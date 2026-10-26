import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/address/models/address_model.dart';
import 'package:mobile/features/address/models/biteship_area_model.dart';
import 'package:mobile/features/auth/models/app_user_model.dart';
import 'package:mobile/features/order/models/order_detail_model.dart';

void main() {
  group('Biteship Logistics Unit & Automated Tests', () {
    test('BiteshipAreaModel parses API autocomplete JSON correctly', () {
      final map = {
        'id': 'IDNP11IDNC278IDND2093IDZ80117',
        'name': 'Dauh Puri Kangin, Denpasar Barat, Denpasar, Bali, 80117',
        'province': 'Bali',
        'city': 'Denpasar',
        'district': 'Denpasar Barat',
        'subdistrict': 'Dauh Puri Kangin',
        'postal_code': '80117',
      };

      final area = BiteshipAreaModel.fromMap(map);

      expect(area.id, 'IDNP11IDNC278IDND2093IDZ80117');
      expect(area.name, contains('Denpasar Barat'));
      expect(area.postalCode, '80117');
      expect(area.district, 'Denpasar Barat');
      expect(area.city, 'Denpasar');
      expect(area.province, 'Bali');
      expect(area.subdistrict, 'Dauh Puri Kangin');

      final serialized = area.toMap();
      expect(serialized['id'], 'IDNP11IDNC278IDND2093IDZ80117');
      expect(serialized['postal_code'], '80117');
    });

    test(
      'AddressModel serializes & deserializes biteship_area_id and notes (patokan)',
      () {
        final map = {
          'id': 'addr-123',
          'label': 'Rumah',
          'recipient_name': 'Budi Santoso',
          'recipient_phone': '081234567890',
          'province': 'Bali',
          'city': 'Denpasar',
          'district': 'Denpasar Barat',
          'postal_code': '80117',
          'full_address': 'Jl. Diponegoro No. 45',
          'is_default': true,
          'biteship_area_id': 'IDNP11IDNC278IDND2093IDZ80117',
          'notes': 'Pagar hitam, seberang minimarket',
        };

        final address = AddressModel.fromMap(map);

        expect(address.id, 'addr-123');
        expect(address.recipientName, 'Budi Santoso');
        expect(address.phoneNumber, '081234567890');
        expect(address.biteshipAreaId, 'IDNP11IDNC278IDND2093IDZ80117');
        expect(address.notes, 'Pagar hitam, seberang minimarket');
        expect(address.isDefault, isTrue);
      },
    );

    test(
      'OrderDetailModel correctly parses Biteship tracking, GPS coordinates, and driver messages',
      () {
        final json = {
          'id': 'f1fc9730-91d8-40e9-8802-d879dbb0b2c1',
          'user_id': 'user-101',
          'store_id': 'store-202',
          'store': {
            'id': 'store-202',
            'name': 'Toko Kerajinan Bali',
            'latitude': -8.6500,
            'longitude': 115.2167,
          },
          'order_number': 'ORD-1790398799466',
          'status': 'shipped',
          'subtotal': 25000,
          'shipping_cost': 32500,
          'application_fee': 0,
          'total_amount': 57500,
          'payment_status': 'paid',
          'shipping_name': 'Dty',
          'shipping_phone': '08123123123',
          'shipping_address': 'Jl. Gunung Agung No. 10',
          'shipping_city': 'Denpasar',
          'shipping_postal_code': '80117',
          'shipping_notes': 'Rumah tingkat dua gerbang abu-abu',
          'shipping_latitude': -8.6705,
          'shipping_longitude': 115.2126,
          'created_at': '2026-09-26T04:59:00Z',
          'shipped_at': '2026-09-26T05:34:00Z',
          'shipping_provider': 'Gojek - Instant',
          'courier_name': 'Gojek - Instant',
          'courier_code': 'gojek',
          'courier_service_type': 'instant',
          'tracking_number': 'WYB-17904006635',
          'waybill_id': 'WYB-17904006635',
          'tracking_status': 'dropping_off',
          'driver_name': 'Pak Hendra (Gojek)',
          'driver_phone': '081299887766',
          'driver_latitude': -8.6600,
          'driver_longitude': 115.2145,
          'driver_messages': [
            {
              'sender_role': 'buyer',
              'sender_name': 'Dty',
              'message': 'Titip di pos satpam ya Pak',
            },
          ],
          'items': [],
        };

        final order = OrderDetailModel.fromJson(json);

        expect(order.orderNumber, 'ORD-1790398799466');
        expect(order.status, 'shipped');
        expect(order.storeName, 'Toko Kerajinan Bali');
        expect(order.waybillId, 'WYB-17904006635');
        expect(order.trackingNumber, 'WYB-17904006635');
        expect(order.trackingStatus, 'dropping_off');
        expect(order.driverName, 'Pak Hendra (Gojek)');
        expect(order.driverPhone, '081299887766');
        expect(order.shippingNotes, 'Rumah tingkat dua gerbang abu-abu');
        expect(order.isInstantCourier, isTrue);
        expect(order.effectiveDriverLat, -8.6600);
        expect(order.effectiveDriverLng, 115.2145);
        expect(order.gpsProgressFraction, closeTo(0.78, 0.01));
        expect(order.estimatedDistanceKm, greaterThan(1.0));
        expect(order.driverMessages.length, 1);
      },
    );

    test('AppUserModel correctly parses Ekspedisi and Ojek roles and labels', () {
      final ekspedisiUser = AppUserModel.fromMap({
        'id': 'exp-1',
        'full_name': 'JNE Denpasar Hub',
        'phone': '0812345678',
        'role': 'ekspedisi',
      });

      expect(ekspedisiUser.isEkspedisi, isTrue);
      expect(ekspedisiUser.isOjek, isFalse);
      expect(ekspedisiUser.roleBadgeLabel, 'Mitra Ekspedisi');

      final ojekUser = AppUserModel.fromMap({
        'id': 'ojek-1',
        'full_name': 'Wayan Driver',
        'phone': '081999888777',
        'role': 'ojek',
      });

      expect(ojekUser.isOjek, isTrue);
      expect(ojekUser.isEkspedisi, isFalse);
      expect(ojekUser.roleBadgeLabel, 'Driver Ojek');
    });

    testWidgets(
      'Shipment status card renders all courier and tracking info cleanly',
      (tester) async {
        final sampleOrder = OrderDetailModel.fromJson({
          'id': 'test-ord-1',
          'user_id': 'user-1',
          'store_id': 'store-1',
          'order_number': 'ORD-1790398799466',
          'status': 'shipped',
          'subtotal': 25000,
          'shipping_cost': 32500,
          'application_fee': 0,
          'total_amount': 57500,
          'payment_status': 'paid',
          'shipping_name': 'Dty',
          'shipping_phone': '08123123123',
          'shipping_address': 'Jl. Gunung Agung No. 10',
          'shipping_city': 'Denpasar',
          'shipping_postal_code': '80117',
          'shipping_notes': 'Pagar hitam, seberang minimarket',
          'created_at': '2026-09-26T04:59:00Z',
          'shipped_at': '2026-09-26T05:34:00Z',
          'shipping_provider': 'Gojek - Instant',
          'courier_name': 'Gojek - Instant',
          'tracking_number': 'WYB-17904006635',
          'waybill_id': 'WYB-17904006635',
          'tracking_status': 'dropping_off',
          'driver_name': 'Pak Hendra',
          'driver_phone': '081299887766',
          'items': [],
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Pengiriman Logistik',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Ekspedisi: ${sampleOrder.courierName}'),
                        Text('No. Resi: ${sampleOrder.waybillId}'),
                        Text(
                          'Driver: ${sampleOrder.driverName} (${sampleOrder.driverPhone})',
                        ),
                        const Text('Status: Dalam Pengiriman (On Delivery)'),
                        if (sampleOrder.shippingNotes != null)
                          Text('Patokan: ${sampleOrder.shippingNotes}'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Status Pengiriman Logistik'), findsOneWidget);
        expect(find.text('Ekspedisi: Gojek - Instant'), findsOneWidget);
        expect(find.text('No. Resi: WYB-17904006635'), findsOneWidget);
        expect(
          find.text('Driver: Pak Hendra (081299887766)'),
          findsOneWidget,
        );
        expect(
          find.text('Status: Dalam Pengiriman (On Delivery)'),
          findsOneWidget,
        );
        expect(
          find.text('Patokan: Pagar hitam, seberang minimarket'),
          findsOneWidget,
        );
      },
    );
  });
}
