import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/address/models/address_model.dart';
import 'package:mobile/features/address/models/biteship_area_model.dart';
import 'package:mobile/features/auth/models/app_user_model.dart';
import 'package:mobile/features/order/models/order_detail_model.dart';
import 'package:mobile/features/order/widgets/shipment_tracking_section.dart';
import 'package:mobile/features/store/models/store_model.dart';

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

    test('AddressModel & StoreModel parse GPS coordinates and administrative fields', () {
      final address = AddressModel.fromMap({
        'id': 'addr-gps-1',
        'recipient_name': 'Siti',
        'recipient_phone': '081122334455',
        'province': 'Jawa Barat',
        'city': 'Bandung',
        'district': 'Coblong',
        'postal_code': '40132',
        'full_address': 'Jl. Dago No. 10',
        'latitude': -6.8891,
        'longitude': 107.6104,
        'is_default': true,
      });

      expect(address.latitude, -6.8891);
      expect(address.longitude, 107.6104);

      final store = StoreModel.fromMap({
        'id': 'store-gps-1',
        'owner_id': 'owner-1',
        'name': 'Batik Nusantara',
        'slug': 'batik-nusantara',
        'description': 'Batik tulis asli',
        'phone': '081999111222',
        'address': 'Jl. Malioboro No. 5',
        'province': 'DI Yogyakarta',
        'city': 'Yogyakarta',
        'district': 'Gedongtengen',
        'postal_code': '55272',
        'notes': 'Depan halte bus',
        'biteship_area_id': 'IDNP5IDNC552IDZ55272',
        'latitude': -7.7926,
        'longitude': 110.3658,
        'status': 'active',
      });

      expect(store.province, 'DI Yogyakarta');
      expect(store.city, 'Yogyakarta');
      expect(store.district, 'Gedongtengen');
      expect(store.postalCode, '55272');
      expect(store.notes, 'Depan halte bus');
      expect(store.biteshipAreaId, 'IDNP5IDNC552IDZ55272');
      expect(store.latitude, -7.7926);
      expect(store.longitude, 110.3658);
    });

    test(
      'OrderDetailModel handles origin snapshot vs store fallback, courier classification, and resolvedCheckpoints',
      () {
        // 1. Order with explicit origin snapshot + Biteship expedition checkpoints (mixed coords)
        final biteshipExpOrder = OrderDetailModel.fromJson({
          'id': 'ord-bs-exp-1',
          'user_id': 'buyer-1',
          'store_id': 'store-1',
          'store': {
            'id': 'store-1',
            'name': 'Toko Fallback',
            'phone': '08111111111',
            'address': 'Alamat Store Baru',
            'latitude': -6.1000,
            'longitude': 106.7000,
          },
          'origin_contact_name': 'Kopi Nusantara Snapshot',
          'origin_phone': '081288889999',
          'origin_address': 'Jl. Kemang Raya No. 8',
          'origin_city': 'Jakarta Selatan',
          'origin_postal_code': '12730',
          'origin_notes': 'Sebelah toko roti',
          'origin_latitude': -6.2600,
          'origin_longitude': 106.8150,
          'order_number': 'ORD-BS-100',
          'status': 'shipped',
          'subtotal': 100000,
          'shipping_cost': 15000,
          'total_amount': 115000,
          'payment_status': 'paid',
          'shipping_name': 'Andi',
          'shipping_phone': '081377776666',
          'shipping_address': 'Jl. Sudirman No. 1',
          'shipping_latitude': -6.2100,
          'shipping_longitude': 106.8200,
          'created_at': '2026-11-20T10:00:00Z',
          'shipping_provider': 'JNE Reguler',
          'courier_name': 'JNE Reguler',
          'courier_code': 'jne',
          'courier_service_type': 'standard',
          'biteship_order_id': 'bs_order_abc123',
          'waybill_id': 'JNE99887766',
          'tracking_number': 'JNE99887766',
          'tracking_status': 'dropping_off',
          'tracking_history': [
            {
              'status': 'allocated',
              'checkpoint_name': 'Hub Pickup Jakarta Selatan',
              'note': 'Paket dipickup kurir',
              'latitude': -6.2500,
              'longitude': 106.8160,
              'timestamp': '2026-11-20T11:00:00Z',
            },
            {
              'status': 'dropping_off',
              'note': 'Transit Gudang Sortir Pusat',
              'timestamp': '2026-11-20T15:00:00Z',
            },
          ],
          'order_items': [],
        });

        expect(biteshipExpOrder.effectiveOriginName, 'Kopi Nusantara Snapshot');
        expect(biteshipExpOrder.effectiveOriginPhone, '081288889999');
        expect(biteshipExpOrder.effectiveOriginAddress, 'Jl. Kemang Raya No. 8');
        expect(biteshipExpOrder.effectiveOriginNotes, 'Sebelah toko roti');
        expect(biteshipExpOrder.effectiveStoreLat, -6.2600);
        expect(biteshipExpOrder.effectiveStoreLng, 106.8150);
        expect(biteshipExpOrder.isBiteshipManaged, isTrue);
        expect(biteshipExpOrder.isLocalPartnerManaged, isFalse);
        expect(biteshipExpOrder.hasRealDriverPhone, isFalse);
        expect(biteshipExpOrder.isShipmentClosed, isFalse);

        final cps = biteshipExpOrder.resolvedCheckpoints;
        expect(cps.length, 2);
        expect(cps[0].title, 'Hub Pickup Jakarta Selatan');
        expect(cps[0].isEstimatedCoordinate, isFalse);
        expect(cps[0].latitude, -6.2500);
        expect(cps[1].isEstimatedCoordinate, isTrue);
        expect(cps[1].latitude, inInclusiveRange(-6.2600, -6.2100));

        // 2. Local partner order with store fallback & completed status
        final localClosedOrder = OrderDetailModel.fromJson({
          'id': 'ord-local-2',
          'user_id': 'buyer-2',
          'store_id': 'store-2',
          'store': {
            'id': 'store-2',
            'name': 'Warung Sambal Bu Ani',
            'phone': '085612345678',
            'address': 'Jl. Pasar Baru No. 2',
            'notes': 'Masuk gang melati',
            'latitude': -6.1650,
            'longitude': 106.8350,
          },
          'order_number': 'ORD-LOC-200',
          'status': 'completed',
          'total_amount': 45000,
          'payment_status': 'paid',
          'shipping_name': 'Rina',
          'shipping_phone': '081512341234',
          'shipping_address': 'Jl. Sabang No. 9',
          'created_at': '2026-11-20T08:00:00Z',
          'shipping_provider': 'Ojek Lokal UMKM',
          'courier_name': 'Ojek Lokal UMKM',
          'courier_code': 'ojek_lokal',
          'courier_service_type': 'instant',
          'driver_id': 'driver-uuid-1',
          'driver_name': 'Pak Agus',
          'driver_phone': '081900011122',
          'tracking_number': '',
          'tracking_status': 'delivered',
          'order_items': [],
        });

        expect(localClosedOrder.effectiveOriginName, 'Warung Sambal Bu Ani');
        expect(localClosedOrder.effectiveOriginPhone, '085612345678');
        expect(localClosedOrder.effectiveOriginAddress, 'Jl. Pasar Baru No. 2');
        expect(localClosedOrder.effectiveOriginNotes, 'Masuk gang melati');
        expect(localClosedOrder.effectiveStoreLat, -6.1650);
        expect(localClosedOrder.isBiteshipManaged, isFalse);
        expect(localClosedOrder.isLocalPartnerManaged, isTrue);
        expect(localClosedOrder.hasRealDriverPhone, isTrue);
        expect(localClosedOrder.isShipmentClosed, isTrue);
      },
    );

    testWidgets(
      'SellerOriginDetailCard and ShipmentDriverContactCard enforce Biteship Call/Msg rules without fake numbers',
      (tester) async {
        final biteshipNoPhone = OrderDetailModel.fromJson({
          'id': 'ord-widget-1',
          'user_id': 'buyer-1',
          'store_id': 'store-1',
          'origin_contact_name': 'UMKM Keripik Apel',
          'origin_phone': '081234560000',
          'origin_address': 'Jl. Soekarno Hatta No. 12',
          'origin_city': 'Malang',
          'origin_postal_code': '65141',
          'origin_notes': 'Ruko biru',
          'order_number': 'ORD-W-1',
          'status': 'shipped',
          'total_amount': 50000,
          'payment_status': 'paid',
          'shipping_name': 'Budi',
          'shipping_phone': '081200009999',
          'shipping_address': 'Jl. Merdeka No. 1',
          'created_at': '2026-11-20T08:00:00Z',
          'shipping_provider': 'JNE Reguler',
          'courier_name': 'JNE Reguler',
          'courier_code': 'jne',
          'biteship_order_id': 'bs-123',
          'tracking_number': 'JNE12345',
          'waybill_id': 'JNE12345',
          'tracking_status': 'dropping_off',
          'order_items': [],
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    SellerOriginDetailCard(order: biteshipNoPhone),
                    ShipmentDriverContactCard(
                      order: biteshipNoPhone,
                      currentUserRole: 'buyer',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('UMKM Keripik Apel'), findsOneWidget);
        expect(find.text('081234560000'), findsOneWidget);
        expect(find.text('Ruko biru'), findsOneWidget);
        // Never show fake fallback phone 081200001111 or Telepon Kurir button without real driver_phone
        expect(find.textContaining('081200001111'), findsNothing);
        expect(find.text('Telepon Kurir'), findsNothing);
        expect(find.text('In-App Call (VoIP)'), findsNothing);

        // Now test Biteship Instant with real driver_phone
        final biteshipWithPhone = OrderDetailModel.fromJson({
          'id': 'ord-widget-2',
          'user_id': 'buyer-1',
          'store_id': 'store-1',
          'order_number': 'ORD-W-2',
          'status': 'shipped',
          'total_amount': 50000,
          'payment_status': 'paid',
          'shipping_name': 'Budi',
          'shipping_phone': '081200009999',
          'shipping_address': 'Jl. Merdeka No. 1',
          'created_at': '2026-11-20T08:00:00Z',
          'shipping_provider': 'Gojek - Instant',
          'courier_name': 'Gojek - Instant',
          'courier_code': 'gojek',
          'courier_service_type': 'instant',
          'biteship_order_id': 'bs-456',
          'driver_name': 'Pak Joko Gojek',
          'driver_phone': '08188887777',
          'driver_vehicle_plate': 'B 1234 XYZ',
          'tracking_number': 'GK-999',
          'tracking_status': 'picking_up',
          'order_items': [],
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShipmentDriverContactCard(
                order: biteshipWithPhone,
                currentUserRole: 'buyer',
              ),
            ),
          ),
        );

        expect(find.text('Pak Joko Gojek'), findsOneWidget);
        expect(find.text('Telepon Kurir'), findsOneWidget);
        expect(find.text('WhatsApp'), findsOneWidget);
        expect(find.text('In-App Call (VoIP)'), findsNothing);
      },
    );
  });
}
