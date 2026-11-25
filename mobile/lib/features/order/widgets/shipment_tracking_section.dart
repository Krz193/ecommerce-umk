import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/order/models/order_detail_model.dart';
import 'package:mobile/features/order/widgets/in_app_call_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher/url_launcher.dart';

String formatWhatsAppPhone(String rawPhone) {
  final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('0')) return '62${digits.substring(1)}';
  if (digits.startsWith('8')) return '62$digits';
  return digits;
}

Future<void> launchPhoneDialer(BuildContext context, String rawPhone) async {
  final phone = rawPhone.trim();
  if (phone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nomor telepon belum tersedia.')),
    );
    return;
  }

  final uri = Uri(scheme: 'tel', path: phone);
  try {
    final launched = await launchUrl(uri);
    if (launched) return;
  } catch (_) {}

  await Clipboard.setData(ClipboardData(text: phone));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Nomor telepon ($phone) disalin ke clipboard.')),
  );
}

Future<void> launchWhatsAppChat(
  BuildContext context, {
  required String rawPhone,
  required String message,
}) async {
  final waPhone = formatWhatsAppPhone(rawPhone);
  if (waPhone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nomor WhatsApp belum tersedia.')),
    );
    return;
  }

  final uri = Uri.parse(
    'https://wa.me/$waPhone?text=${Uri.encodeComponent(message)}',
  );
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) return;
  } catch (_) {}

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Tidak dapat membuka aplikasi WhatsApp.')),
  );
}

Future<void> launchSmsMessage(
  BuildContext context, {
  required String rawPhone,
  required String message,
}) async {
  final phone = rawPhone.trim();
  if (phone.isEmpty) return;
  final uri = Uri(
    scheme: 'sms',
    path: phone,
    queryParameters: {'body': message},
  );
  try {
    final launched = await launchUrl(uri);
    if (launched) return;
  } catch (_) {}

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Tidak dapat membuka aplikasi SMS.')),
  );
}

String formatOrderTrackingStatus(String? status) {
  if (status == null || status.isEmpty) return '-';
  switch (status.toLowerCase()) {
    case 'pending':
      return 'Menunggu Penjemputan / Diproses';
    case 'ready_to_ship':
      return 'Siap Dijemput Kurir Toko';
    case 'allocated':
    case 'confirmed':
      return 'Kurir Dialokasikan (Allocated)';
    case 'picking_up':
      return 'Kurir Menuju Penjemputan (Picking Up)';
    case 'picked':
      return 'Paket Telah Diambil Kurir (Picked)';
    case 'dropping_off':
    case 'on_delivery':
    case 'in_transit':
      return 'Dalam Pengiriman (On Delivery)';
    case 'delivered':
    case 'completed':
      return 'Paket Telah Sampai (Delivered)';
    case 'cancelled':
    case 'cancelled_by_courier':
      return 'Pengiriman Dibatalkan';
    case 'rejected':
      return 'Pengiriman Ditolak';
    case 'courier_not_found':
      return 'Kurir Belum Ditemukan';
    default:
      return status.toUpperCase();
  }
}

class SellerOriginDetailCard extends StatelessWidget {
  final OrderDetailModel order;
  final bool isSellerView;
  final VoidCallback? onEditStoreLocation;

  const SellerOriginDetailCard({
    super.key,
    required this.order,
    this.isSellerView = false,
    this.onEditStoreLocation,
  });

  @override
  Widget build(BuildContext context) {
    final originPhone = order.effectiveOriginPhone;
    final originCityPostal = [
      order.effectiveOriginCity,
      order.effectiveOriginPostalCode,
    ].where((e) => e != null && e.trim().isNotEmpty).join(' • ');
    final fullAddressLine = [
      order.effectiveOriginAddress,
      if (originCityPostal.isNotEmpty) originCityPostal,
    ].join('\n');
    final hasCustomCoords =
        order.originLatitude != null || order.storeLatitude != null;
    final coordText =
        '${order.effectiveStoreLat.toStringAsFixed(5)}, ${order.effectiveStoreLng.toStringAsFixed(5)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.indigo.shade50,
                child: Icon(
                  Icons.storefront_rounded,
                  color: Colors.indigo.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail Penjual / Pengirim (Origin)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      order.effectiveOriginName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSellerView)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasCustomCoords
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasCustomCoords ? 'GPS Siap' : 'GPS Default',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasCustomCoords
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow(
            Icons.phone_outlined,
            'Telepon / WA Pengirim',
            originPhone ?? 'Belum dicantumkan',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.location_on_outlined,
            'Alamat Asal Pengiriman',
            fullAddressLine,
          ),
          if (order.effectiveOriginNotes != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.signpost_outlined,
              'Patokan Lokasi Toko',
              order.effectiveOriginNotes!,
            ),
          ],
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.gps_fixed_rounded,
            'Titik Koordinat Origin',
            coordText,
            monospace: true,
          ),
          const SizedBox(height: 12),
          if (!isSellerView)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (order.storeId != null && order.storeId!.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/stores/${order.storeId}'),
                    icon: const Icon(Icons.store_outlined, size: 16),
                    label: const Text('Kunjungi Toko'),
                  ),
                if (originPhone != null) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => launchWhatsAppChat(
                      context,
                      rawPhone: originPhone,
                      message:
                          'Halo ${order.effectiveOriginName}, saya ingin menanyakan pesanan ${order.orderNumber}.',
                    ),
                    icon: const Icon(Icons.chat_outlined, size: 16),
                    label: const Text('Chat WA Penjual'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => launchPhoneDialer(context, originPhone),
                    icon: const Icon(Icons.call_outlined, size: 16),
                    label: const Text('Telepon'),
                  ),
                ],
              ],
            )
          else if (onEditStoreLocation != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEditStoreLocation,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                label: const Text('Edit Profil & Titik Lokasi Toko'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool monospace = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: monospace ? 'monospace' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ShipmentMapAndTrackingCard extends StatelessWidget {
  final OrderDetailModel order;
  final bool isSyncing;
  final VoidCallback? onSyncTracking;

  const ShipmentMapAndTrackingCard({
    super.key,
    required this.order,
    this.isSyncing = false,
    this.onSyncTracking,
  });

  bool get _showActiveTracking =>
      order.isShipmentActive || order.isShipmentClosed;

  @override
  Widget build(BuildContext context) {
    final distanceKm = order.estimatedDistanceKm.toStringAsFixed(1);
    final isInstantMode = order.isInstantCourier;
    final storeCoord =
        '${order.effectiveStoreLat.toStringAsFixed(5)}, ${order.effectiveStoreLng.toStringAsFixed(5)}';
    final destCoord =
        '${order.effectiveDestLat.toStringAsFixed(5)}, ${order.effectiveDestLng.toStringAsFixed(5)}';
    final driverCoord =
        '${order.effectiveDriverLat.toStringAsFixed(5)}, ${order.effectiveDriverLng.toStringAsFixed(5)}';

    final String modeBadgeLabel;
    final Color modeBadgeColor;
    if (!_showActiveTracking) {
      modeBadgeLabel = 'PRATINJAU RUTE';
      modeBadgeColor = const Color(0xFF475569);
    } else if (isInstantMode) {
      modeBadgeLabel = 'REALTIME INSTANT';
      modeBadgeColor = Colors.green.shade700;
    } else {
      modeBadgeLabel = 'PER-POINT EKSPEDISI';
      modeBadgeColor = Colors.blue.shade800;
    }

    final checkpoints = (!isInstantMode && _showActiveTracking)
        ? order.resolvedCheckpoints
        : const <ShipmentCheckpointPoint>[];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightBlue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInstantMode
                    ? Icons.two_wheeler_rounded
                    : Icons.route_rounded,
                size: 18,
                color: modeBadgeColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Peta Pengiriman & GPS ($distanceKm km)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: modeBadgeColor,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  modeBadgeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _buildInteractiveMap(context, checkpoints),

          if (isInstantMode && _showActiveTracking) ...[
            _buildInstantStageStepper(order),
            const SizedBox(height: 10),
          ],

          _buildCoordinateRow(
            icon: Icons.storefront_rounded,
            color: Colors.indigo,
            title: 'Titik Jemput (Origin): ${order.effectiveOriginName}',
            subtitle: 'GPS: $storeCoord',
          ),
          const SizedBox(height: 6),

          if (_showActiveTracking && isInstantMode) ...[
            _buildCoordinateRow(
              icon: Icons.two_wheeler_rounded,
              color: Colors.green.shade700,
              title:
                  'Posisi Live Driver (${formatOrderTrackingStatus(order.trackingStatus)})',
              subtitle:
                  'GPS: $driverCoord'
                  '${order.driverVehiclePlate?.isNotEmpty == true ? ' • ${order.driverVehiclePlate}' : ''}'
                  '${order.driverLastUpdated != null ? ' • Update ${DateFormatter.formatDateTime(order.driverLastUpdated!.toIso8601String())}' : ''}',
            ),
            const SizedBox(height: 6),
          ],

          _buildCoordinateRow(
            icon: Icons.location_on_rounded,
            color: Colors.red.shade700,
            title: 'Titik Tujuan (Pembeli): ${order.shippingName}',
            subtitle: 'GPS: $destCoord',
          ),

          if (!isInstantMode && _showActiveTracking) ...[
            const SizedBox(height: 12),
            _buildPerPointTimelineSection(checkpoints),
          ],

          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (onSyncTracking != null && _showActiveTracking)
                ElevatedButton.icon(
                  onPressed: isSyncing ? null : onSyncTracking,
                  icon: isSyncing
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync_rounded, size: 15),
                  label: Text(
                    isInstantMode ? 'Sync Status' : 'Sinkronisasi Resi Live',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              if (order.trackingUrl != null &&
                  order.trackingUrl!.trim().isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _openExternalTrackingUrl(context, order.trackingUrl!),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text(
                    'Buka Live Tracking Biteship',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _openGoogleMapsRoute(context, order),
                icon: const Icon(Icons.map_outlined, size: 15),
                label: const Text(
                  'Buka Rute Google Maps',
                  style: TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final coordToCopy = (_showActiveTracking && isInstantMode)
                      ? driverCoord
                      : destCoord;
                  await Clipboard.setData(ClipboardData(text: coordToCopy));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Koordinat GPS ($coordToCopy) disalin.'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text(
                  'Salin Titik GPS',
                  style: TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveMap(
    BuildContext context,
    List<ShipmentCheckpointPoint> checkpoints,
  ) {
    final storePos = ll.LatLng(order.effectiveStoreLat, order.effectiveStoreLng);
    final destPos = ll.LatLng(order.effectiveDestLat, order.effectiveDestLng);
    final driverPos = ll.LatLng(
      order.effectiveDriverLat,
      order.effectiveDriverLng,
    );

    final routePoints = <ll.LatLng>[storePos];
    if (_showActiveTracking) {
      if (order.isInstantCourier) {
        routePoints.add(driverPos);
      } else {
        for (final cp in checkpoints) {
          routePoints.add(ll.LatLng(cp.latitude, cp.longitude));
        }
      }
    }
    routePoints.add(destPos);

    final bounds = LatLngBounds.fromPoints(routePoints);
    final isDelivered = order.isShipmentClosed;

    final markers = <Marker>[
      _buildLabeledPinMarker(
        point: storePos,
        label: 'Toko UMK',
        badgeColor: Colors.indigo.shade800,
        icon: Icons.storefront_rounded,
      ),
      _buildLabeledPinMarker(
        point: destPos,
        label: 'Tujuan',
        badgeColor: Colors.red.shade700,
        icon: Icons.location_on_rounded,
      ),
    ];

    if (_showActiveTracking && order.isInstantCourier) {
      markers.add(
        Marker(
          point: driverPos,
          width: 105,
          height: 58,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade800,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 3),
                  ],
                ),
                child: Text(
                  order.isBiteshipManaged ? 'Driver Instant' : 'Ojek Lokal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade600.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.two_wheeler_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_showActiveTracking && !order.isInstantCourier) {
      for (var i = 0; i < checkpoints.length; i++) {
        final cp = checkpoints[i];
        final isLatest = i == checkpoints.length - 1;
        markers.add(
          Marker(
            point: ll.LatLng(cp.latitude, cp.longitude),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: isLatest ? Colors.orange.shade700 : Colors.blue.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: (isLatest ? Colors.orange : Colors.blue)
                        .withValues(alpha: 0.35),
                    blurRadius: isLatest ? 8 : 4,
                    spreadRadius: isLatest ? 2 : 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '#${cp.index}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      height: 220,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 42,
                    vertical: 38,
                  ),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ecommerce.umk.mobile',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 6.0,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    Polyline(
                      points: routePoints,
                      strokeWidth: 3.5,
                      color: !_showActiveTracking
                          ? Colors.blueGrey
                          : (order.isInstantCourier
                                ? const Color(0xFF10B981)
                                : const Color(0xFF0284C7)),
                    ),
                  ],
                ),
                MarkerLayer(markers: markers),
              ],
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: !_showActiveTracking
                            ? Colors.orange
                            : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      !_showActiveTracking
                          ? 'Menunggu Pengiriman'
                          : (isDelivered
                                ? 'Paket Sampai'
                                : (order.isInstantCourier
                                      ? 'Live Driver (${(order.gpsProgressFraction * 100).round()}%)'
                                      : '${checkpoints.length} Titik Checkpoint')),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Text(
                  '${order.estimatedDistanceKm.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '© OpenStreetMap',
                  style: TextStyle(fontSize: 8, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildLabeledPinMarker({
    required ll.LatLng point,
    required String label,
    required Color badgeColor,
    required IconData icon,
  }) {
    return Marker(
      point: point,
      width: 90,
      height: 52,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 3),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Icon(icon, color: badgeColor, size: 22),
        ],
      ),
    );
  }

  Widget _buildInstantStageStepper(OrderDetailModel order) {
    final stages = [
      ('allocated', 'Alokasi'),
      ('picking_up', 'Jemput'),
      ('picked', 'Diambil'),
      ('dropping_off', 'Diantar'),
      ('delivered', 'Sampai'),
    ];
    final ts = (order.trackingStatus ?? '').toLowerCase();
    int activeIndex = 0;
    if (order.status == 'completed' || ts == 'delivered') {
      activeIndex = 4;
    } else if (ts == 'dropping_off' || ts == 'on_delivery' || ts == 'in_transit') {
      activeIndex = 3;
    } else if (ts == 'picked') {
      activeIndex = 2;
    } else if (ts == 'picking_up') {
      activeIndex = 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: stages.asMap().entries.map((entry) {
          final idx = entry.key;
          final label = entry.value.$2;
          final done = idx <= activeIndex;
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (idx > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: done ? Colors.green : Colors.grey.shade300,
                        ),
                      ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: done ? Colors.green.shade700 : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: done
                          ? const Icon(
                              Icons.check,
                              size: 9,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (idx < stages.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: idx < activeIndex
                              ? Colors.green
                              : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: done ? FontWeight.bold : FontWeight.normal,
                    color: done ? Colors.green.shade900 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPerPointTimelineSection(
    List<ShipmentCheckpointPoint> checkpoints,
  ) {
    final reversed = checkpoints.reversed.toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, size: 16, color: Colors.blue.shade800),
              const SizedBox(width: 6),
              const Text(
                'Riwayat Pelacakan Per-Titik (Checkpoints)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (reversed.isEmpty)
            const Text(
              'Belum ada titik checkpoint tercatat.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          else
            ...reversed.asMap().entries.map((entry) {
              final idx = entry.key;
              final cp = entry.value;
              final isLatest = idx == 0;
              final isLastItem = idx == reversed.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isLatest
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${cp.index}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!isLastItem)
                        Container(
                          width: 2,
                          height: 44,
                          color: Colors.blue.shade100,
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cp.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isLatest
                                  ? Colors.orange.shade900
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cp.note,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (cp.timestamp != null)
                                DateFormatter.formatDateTime(
                                  cp.timestamp!.toIso8601String(),
                                ),
                              '${cp.latitude.toStringAsFixed(4)}, ${cp.longitude.toStringAsFixed(4)}'
                                  '${cp.isEstimatedCoordinate ? ' (Est. Rute)' : ' (GPS Hub)'}',
                            ].join(' • '),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCoordinateRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openExternalTrackingUrl(
    BuildContext context,
    String rawUrl,
  ) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka link pelacakan.')),
      );
    }
  }

  Future<void> _openGoogleMapsRoute(
    BuildContext context,
    OrderDetailModel order,
  ) async {
    final url =
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${order.effectiveStoreLat},${order.effectiveStoreLng}'
        '&destination=${order.effectiveDestLat},${order.effectiveDestLng}'
        '${_showActiveTracking && order.isInstantCourier ? '&waypoints=${order.effectiveDriverLat},${order.effectiveDriverLng}' : ''}'
        '&travelmode=driving';

    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka aplikasi peta GPS.')),
      );
    }
  }
}

class ShipmentDriverContactCard extends StatelessWidget {
  final OrderDetailModel order;
  final String currentUserRole; // 'buyer' or 'seller'
  final VoidCallback? onOrderMutated;

  const ShipmentDriverContactCard({
    super.key,
    required this.order,
    required this.currentUserRole,
    this.onOrderMutated,
  });

  @override
  Widget build(BuildContext context) {
    if (!order.isShipmentActive && !order.isShipmentClosed) {
      return const SizedBox.shrink();
    }

    final courierDisplay =
        order.courierName ?? order.shippingProvider ?? 'Kurir';

    // Mode 1: Biteship External Courier (Gojek/Grab/JNE/SiCepat/J&T/AnterAja)
    if (order.isBiteshipManaged) {
      if (!order.hasRealDriverPhone) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    order.isInstantCourier
                        ? Icons.hourglass_top_rounded
                        : Icons.local_shipping_outlined,
                    color: Colors.amber.shade900,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.isInstantCourier
                          ? 'Menunggu Alokasi Driver $courierDisplay'
                          : 'Pengiriman via Hub Ekspedisi Biteship ($courierDisplay)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                order.isInstantCourier
                    ? 'Nomor telepon kurir akan muncul otomatis setelah driver Biteship menerima penugasan pickup.'
                    : 'Ekspedisi reguler diproses melalui jaringan hub. Gunakan tombol Sinkronisasi Resi atau Link Tracking untuk memantau paket.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
              ),
              if (order.trackingUrl != null &&
                  order.trackingUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(order.trackingUrl!.trim());
                    if (uri != null) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text('Buka Link Pelacakan Biteship'),
                ),
              ],
            ],
          ),
        );
      }

      // Biteship with real driver_phone
      final realPhone = order.driverPhone!.trim();
      final driverTitle = order.driverName?.trim().isNotEmpty == true
          ? order.driverName!.trim()
          : 'Kurir $courierDisplay';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.green.shade700,
                  child: Icon(
                    order.isInstantCourier
                        ? Icons.two_wheeler_rounded
                        : Icons.local_shipping_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '$realPhone${order.driverVehiclePlate?.isNotEmpty == true ? ' • ${order.driverVehiclePlate}' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade800,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'BITESHIP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (order.isShipmentClosed)
              Text(
                'Pengiriman telah selesai/dibatalkan. Kontak langsung ke driver Biteship dinonaktifkan.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => launchPhoneDialer(context, realPhone),
                    icon: const Icon(Icons.call_rounded, size: 15),
                    label: const Text(
                      'Telepon Kurir',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => launchWhatsAppChat(
                      context,
                      rawPhone: realPhone,
                      message:
                          'Halo $driverTitle, terkait pengiriman pesanan ${order.orderNumber} (${order.shippingName}).',
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 15),
                    label: const Text(
                      'WhatsApp',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => launchSmsMessage(
                      context,
                      rawPhone: realPhone,
                      message:
                          'Halo, terkait pesanan ${order.orderNumber} ke ${order.shippingAddress}',
                    ),
                    icon: const Icon(Icons.sms_outlined, size: 15),
                    label: const Text('SMS', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    // Mode 2: Internal Local Partner (driver_id or local courier)
    final hasLocalDriver =
        (order.driverId != null && order.driverId!.isNotEmpty) ||
        (order.driverName != null && order.driverName!.trim().isNotEmpty);

    if (!hasLocalDriver && order.isLocalPartnerManaged) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          children: [
            Icon(Icons.two_wheeler_rounded, size: 18, color: Colors.grey),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Menunggu mitra driver lokal mengambil penugasan pengiriman ini.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    final localPhone = (order.driverPhone ?? '').trim();
    final localDriverName = order.driverName?.trim().isNotEmpty == true
        ? order.driverName!.trim()
        : 'Mitra Kurir Lokal';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.green.shade700,
                child: Icon(
                  order.isInstantCourier
                      ? Icons.two_wheeler_rounded
                      : Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localDriverName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      localPhone.isNotEmpty
                          ? '$localPhone${order.driverVehiclePlate?.isNotEmpty == true ? ' • ${order.driverVehiclePlate}' : ''}'
                          : 'Terhubung via In-App Call & Chat',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (order.driverMessages.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${order.driverMessages.length} pesan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: order.isShipmentClosed
                      ? null
                      : () {
                          showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => InAppCallDialog(
                              orderId: order.id,
                              orderNumber: order.orderNumber,
                              remotePartyName: localDriverName,
                              remotePartyPhone: localPhone,
                              callerRole: currentUserRole,
                            ),
                          );
                        },
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                  label: Text(
                    order.isShipmentClosed
                        ? 'Call Ditutup'
                        : 'In-App Call (VoIP)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openInAppDriverChatSheet(
                    context,
                    order: order,
                    senderRole: currentUserRole,
                    onMessageSent: onOrderMutated,
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: Text(
                    order.isShipmentClosed
                        ? 'Riwayat Chat'
                        : 'Chat Driver',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade800,
                    side: BorderSide(color: Colors.green.shade700),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> openInAppDriverChatSheet(
  BuildContext context, {
  required OrderDetailModel order,
  required String senderRole,
  VoidCallback? onMessageSent,
}) async {
  final messageController = TextEditingController();
  final rawPhone = (order.driverPhone ?? '').trim();
  final isClosed = order.isShipmentClosed;

  const quickTemplates = [
    'Halo Pak, mohon kabari jika sudah dekat ya.',
    'Titip di pos satpam / pagar depan ya Pak.',
    'Saya sudah menunggu di lokasi.',
    'Patokan alamat sesuai catatan pesanan ya Pak.',
  ];

  RealtimeChannel? chatChannel;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      var messages = List<Map<String, dynamic>>.from(order.driverMessages);
      var isSending = false;
      var subscribed = false;

      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          if (!subscribed) {
            subscribed = true;
            supabase
                .from('orders')
                .select('driver_messages')
                .eq('id', order.id)
                .maybeSingle()
                .then((val) {
              if (val != null &&
                  val['driver_messages'] is List &&
                  sheetCtx.mounted) {
                setSheetState(() {
                  messages = (val['driver_messages'] as List)
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                });
              }
            });

            chatChannel = supabase
                .channel('driver_chat_$senderRole:order_${order.id}')
                .onPostgresChanges(
                  event: PostgresChangeEvent.update,
                  schema: 'public',
                  table: 'orders',
                  filter: PostgresChangeFilter(
                    type: PostgresChangeFilterType.eq,
                    column: 'id',
                    value: order.id,
                  ),
                  callback: (payload) {
                    final raw = payload.newRecord['driver_messages'];
                    if (raw is List && sheetCtx.mounted) {
                      setSheetState(() {
                        messages = raw
                            .whereType<Map>()
                            .map((e) => Map<String, dynamic>.from(e))
                            .toList();
                      });
                    }
                  },
                )
                .subscribe();
          }

          Future<void> sendInAppMessage(String text) async {
            if (isClosed) return;
            final trimmed = text.trim();
            if (trimmed.isEmpty || isSending) return;
            setSheetState(() => isSending = true);
            try {
              final res = await supabase.rpc(
                'append_order_driver_message',
                params: {
                  'p_order_id': order.id,
                  'p_message': trimmed,
                  'p_sender_role': senderRole,
                },
              );
              messageController.clear();
              if (res is List) {
                setSheetState(() {
                  messages = res
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
                });
              }
              onMessageSent?.call();
            } catch (e) {
              if (sheetCtx.mounted) {
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  SnackBar(content: Text('Gagal mengirim pesan: $e')),
                );
              }
            } finally {
              if (sheetCtx.mounted) {
                setSheetState(() => isSending = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.shade700,
                      child: const Icon(
                        Icons.two_wheeler_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chat ${order.driverName ?? "Mitra Kurir"}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            rawPhone.isNotEmpty
                                ? 'Order ${order.orderNumber} • $rawPhone'
                                : 'Order ${order.orderNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (rawPhone.isNotEmpty && !isClosed) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchWhatsAppChat(
                            sheetCtx,
                            rawPhone: rawPhone,
                            message:
                                'Halo Pak ${order.driverName ?? "Driver"}, terkait pesanan ${order.orderNumber} (${order.shippingName}).',
                          ),
                          icon: const Icon(Icons.open_in_new, size: 15),
                          label: const Text(
                            'Chat WhatsApp',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchSmsMessage(
                            sheetCtx,
                            rawPhone: rawPhone,
                            message:
                                'Halo Pak, terkait pesanan ${order.orderNumber} ke ${order.shippingAddress}',
                          ),
                          icon: const Icon(Icons.sms_outlined, size: 15),
                          label: const Text(
                            'Kirim SMS',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                if (!isClosed) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: quickTemplates.map((tpl) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(
                              tpl,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () => sendInAppMessage(tpl),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: messages.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              isClosed
                                  ? 'Tidak ada riwayat pesan pada pengiriman ini.'
                                  : 'Belum ada pesan in-app dengan driver. Pilih template cepat atau ketik pesan di bawah.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: messages.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final msg = messages[idx];
                            final role =
                                msg['sender_role']?.toString() ?? 'buyer';
                            final isMine = role == senderRole;
                            return Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? Colors.green.shade700
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMine
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${msg['sender_name'] ?? 'Pengguna'} (${role.toUpperCase()})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isMine
                                            ? Colors.white70
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      msg['message']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isMine
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),

                if (isClosed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Percakapan ditutup (read-only) karena pesanan telah selesai atau dibatalkan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          decoration: const InputDecoration(
                            hintText: 'Tulis pesan ke mitra driver...',
                            isDense: true,
                          ),
                          onSubmitted: sendInAppMessage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isSending
                            ? null
                            : () => sendInAppMessage(messageController.text),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Kirim'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      );
    },
  );

  if (chatChannel != null) {
    await supabase.removeChannel(chatChannel!);
  }
  messageController.dispose();
}
