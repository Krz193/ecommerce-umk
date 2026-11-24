import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mobile/core/theme/app_colors.dart';

class NominatimPlaceResult {
  final String displayName;
  final ll.LatLng point;

  const NominatimPlaceResult({
    required this.displayName,
    required this.point,
  });
}

class MapPointPickerField extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? initialQuery;
  final String label;
  final String helperText;
  final Color accentColor;
  final ValueChanged<ll.LatLng> onPointSelected;
  final double previewHeight;

  const MapPointPickerField({
    super.key,
    required this.latitude,
    required this.longitude,
    this.initialQuery,
    this.label = 'Titik Lokasi GPS (Pinpoint Peta)',
    this.helperText =
        'Ketuk peta untuk menentukan titik koordinat akurat bagi kurir instan & pelacakan.',
    this.accentColor = AppColors.primary,
    required this.onPointSelected,
    this.previewHeight = 170,
  });

  static const ll.LatLng defaultIndonesiaCenter = ll.LatLng(-6.2088, 106.8456);

  static final Map<String, ll.LatLng> _fallbackCityCoordinates = {
    'jakarta': const ll.LatLng(-6.2088, 106.8456),
    'jakarta selatan': const ll.LatLng(-6.2615, 106.8106),
    'jakarta pusat': const ll.LatLng(-6.1865, 106.8341),
    'jakarta barat': const ll.LatLng(-6.1674, 106.7637),
    'jakarta timur': const ll.LatLng(-6.2250, 106.9004),
    'jakarta utara': const ll.LatLng(-6.1384, 106.8639),
    'cilandak': const ll.LatLng(-6.2913, 106.7985),
    'denpasar': const ll.LatLng(-8.6705, 115.2126),
    'denpasar barat': const ll.LatLng(-8.6623, 115.1972),
    'badung': const ll.LatLng(-8.5819, 115.1770),
    'bali': const ll.LatLng(-8.4095, 115.1889),
    'bandung': const ll.LatLng(-6.9175, 107.6191),
    'surabaya': const ll.LatLng(-7.2575, 112.7521),
    'yogyakarta': const ll.LatLng(-7.7956, 110.3695),
    'sleman': const ll.LatLng(-7.7156, 110.3556),
    'semarang': const ll.LatLng(-6.9667, 110.4167),
    'medan': const ll.LatLng(3.5952, 98.6722),
    'makassar': const ll.LatLng(-5.1477, 119.4327),
    'palembang': const ll.LatLng(-2.9761, 104.7754),
    'tangerang': const ll.LatLng(-6.1783, 106.6319),
    'tangerang selatan': const ll.LatLng(-6.2886, 106.7179),
    'bekasi': const ll.LatLng(-6.2383, 106.9756),
    'depok': const ll.LatLng(-6.4025, 106.7942),
    'bogor': const ll.LatLng(-6.5971, 106.8060),
    'malang': const ll.LatLng(-7.9666, 112.6326),
    'solo': const ll.LatLng(-7.5755, 110.8243),
    'surakarta': const ll.LatLng(-7.5755, 110.8243),
    'balikpapan': const ll.LatLng(-1.2379, 116.8529),
    'banjarmasin': const ll.LatLng(-3.3186, 114.5944),
    'pontianak': const ll.LatLng(-0.0263, 109.3425),
    'manado': const ll.LatLng(1.4748, 124.8421),
    'mataram': const ll.LatLng(-8.5833, 116.1167),
  };

  /// Queries OpenStreetMap Nominatim for Indonesian place suggestions with a 5s timeout
  /// and graceful fallback to local city coordinate lookup.
  static Future<List<NominatimPlaceResult>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'format': 'json',
          'countrycodes': 'id',
          'limit': '5',
          'q': trimmed,
        },
      );
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      req.headers.set(HttpHeaders.userAgentHeader, 'com.ecommerce.umk.mobile');
      req.headers.set(HttpHeaders.acceptLanguageHeader, 'id,en');

      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final rawBody = await res
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 5));
        final decoded = jsonDecode(rawBody);
        if (decoded is List && decoded.isNotEmpty) {
          final results = <NominatimPlaceResult>[];
          for (final item in decoded) {
            if (item is Map) {
              final lat = double.tryParse(item['lat']?.toString() ?? '');
              final lon = double.tryParse(item['lon']?.toString() ?? '');
              final name = item['display_name']?.toString() ?? trimmed;
              if (lat != null && lon != null) {
                results.add(
                  NominatimPlaceResult(
                    displayName: name,
                    point: ll.LatLng(lat, lon),
                  ),
                );
              }
            }
          }
          if (results.isNotEmpty) return results;
        }
      }
    } catch (_) {
      // Fallback gracefully when offline or rate-limited
    } finally {
      client.close(force: true);
    }

    final lower = trimmed.toLowerCase();
    final fallbackMatches = <NominatimPlaceResult>[];
    _fallbackCityCoordinates.forEach((key, coords) {
      if (lower.contains(key) || key.contains(lower)) {
        fallbackMatches.add(
          NominatimPlaceResult(
            displayName: '${key[0].toUpperCase()}${key.substring(1)}, Indonesia',
            point: coords,
          ),
        );
      }
    });
    return fallbackMatches;
  }

  /// Resolves a single best LatLng coordinate for auto-centering when selecting a Biteship Area.
  static Future<ll.LatLng?> geocodeQuery(String query) async {
    final results = await searchPlaces(query);
    if (results.isNotEmpty) return results.first.point;
    return null;
  }

  static Future<ll.LatLng?> showPickerDialog(
    BuildContext context, {
    double? initialLatitude,
    double? initialLongitude,
    String? initialQuery,
    String title = 'Pilih Titik GPS di Peta',
    Color accentColor = AppColors.primary,
  }) {
    return showDialog<ll.LatLng>(
      context: context,
      builder: (ctx) => _MapPointPickerModal(
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        initialQuery: initialQuery,
        title: title,
        accentColor: accentColor,
      ),
    );
  }

  @override
  State<MapPointPickerField> createState() => _MapPointPickerFieldState();
}

class _MapPointPickerFieldState extends State<MapPointPickerField> {
  final MapController _previewController = MapController();

  bool get _hasValidPoint =>
      widget.latitude != null &&
      widget.longitude != null &&
      widget.latitude != 0 &&
      widget.longitude != 0;

  ll.LatLng get _displayCenter => _hasValidPoint
      ? ll.LatLng(widget.latitude!, widget.longitude!)
      : MapPointPickerField.defaultIndonesiaCenter;

  @override
  void didUpdateWidget(covariant MapPointPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.latitude != widget.latitude ||
            oldWidget.longitude != widget.longitude) &&
        _hasValidPoint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _previewController.move(_displayCenter, 15.0);
        } catch (_) {}
      });
    }
  }

  Future<void> _openPicker() async {
    final picked = await MapPointPickerField.showPickerDialog(
      context,
      initialLatitude: widget.latitude,
      initialLongitude: widget.longitude,
      initialQuery: widget.initialQuery,
      title: widget.label,
      accentColor: widget.accentColor,
    );

    if (picked != null) {
      widget.onPointSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordText = _hasValidPoint
        ? '${widget.latitude!.toStringAsFixed(6)}, ${widget.longitude!.toStringAsFixed(6)}'
        : 'Belum ditentukan (ketuk peta untuk set titik)';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasValidPoint
              ? widget.accentColor.withValues(alpha: 0.45)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pin_drop_rounded, color: widget.accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _hasValidPoint
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _hasValidPoint ? 'GPS Terpasang' : 'Belum di-Pin',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _hasValidPoint
                        ? Colors.green.shade800
                        : Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.helperText,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _openPicker,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: widget.previewHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    AbsorbPointer(
                      child: FlutterMap(
                        mapController: _previewController,
                        options: MapOptions(
                          initialCenter: _displayCenter,
                          initialZoom: _hasValidPoint ? 15.0 : 11.5,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.ecommerce.umk.mobile',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _displayCenter,
                                width: 44,
                                height: 44,
                                alignment: Alignment.topCenter,
                                child: Icon(
                                  Icons.location_on_rounded,
                                  color: _hasValidPoint
                                      ? Colors.red.shade600
                                      : Colors.grey.shade700,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_location_alt_rounded,
                              size: 14,
                              color: widget.accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Atur Pin Peta',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: widget.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  coordText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: _hasValidPoint
                        ? Colors.black87
                        : Colors.orange.shade900,
                    fontWeight: _hasValidPoint
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openPicker,
                icon: const Icon(Icons.my_location_rounded, size: 16),
                label: Text(_hasValidPoint ? 'Ubah Titik' : 'Set Map Point'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapPointPickerModal extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialQuery;
  final String title;
  final Color accentColor;

  const _MapPointPickerModal({
    this.initialLatitude,
    this.initialLongitude,
    this.initialQuery,
    required this.title,
    required this.accentColor,
  });

  @override
  State<_MapPointPickerModal> createState() => _MapPointPickerModalState();
}

class _MapPointPickerModalState extends State<_MapPointPickerModal> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  late ll.LatLng _pickedPoint;
  List<NominatimPlaceResult> _suggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final hasInit =
        widget.initialLatitude != null &&
        widget.initialLongitude != null &&
        widget.initialLatitude != 0 &&
        widget.initialLongitude != 0;
    _pickedPoint = hasInit
        ? ll.LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : MapPointPickerField.defaultIndonesiaCenter;

    if (!hasInit &&
        widget.initialQuery != null &&
        widget.initialQuery!.trim().length >= 3) {
      _searchController.text = widget.initialQuery!.trim();
      _autoCenterFromQuery(widget.initialQuery!.trim());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _autoCenterFromQuery(String query) async {
    final point = await MapPointPickerField.geocodeQuery(query);
    if (point != null && mounted) {
      setState(() {
        _pickedPoint = point;
      });
      try {
        _mapController.move(point, 14.5);
      } catch (_) {}
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(val.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await MapPointPickerField.searchPlaces(query);
    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _isSearching = false;
    });
  }

  Future<void> _openManualCoordinateDialog() async {
    final latCtrl = TextEditingController(
      text: _pickedPoint.latitude.toStringAsFixed(6),
    );
    final lngCtrl = TextEditingController(
      text: _pickedPoint.longitude.toStringAsFixed(6),
    );

    final confirmed = await showDialog<ll.LatLng>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Input Koordinat Manual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Latitude (contoh: -6.208800)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lngCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Longitude (contoh: 106.845600)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latCtrl.text.trim());
              final lng = double.tryParse(lngCtrl.text.trim());
              if (lat == null ||
                  lng == null ||
                  lat < -90 ||
                  lat > 90 ||
                  lng < -180 ||
                  lng > 180) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Koordinat Latitude/Longitude tidak valid.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, ll.LatLng(lat, lng));
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );

    latCtrl.dispose();
    lngCtrl.dispose();

    if (confirmed != null && mounted) {
      setState(() => _pickedPoint = confirmed);
      try {
        _mapController.move(confirmed, 16.0);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: 'Input Koordinat Manual',
              onPressed: _openManualCoordinateDialog,
              icon: const Icon(Icons.edit_location_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar (Nominatim OSM)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (val) => _performSearch(val.trim()),
                decoration: InputDecoration(
                  hintText: 'Cari nama jalan, kecamatan, kota, atau patokan...',
                  prefixIcon: Icon(Icons.search, color: widget.accentColor),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _suggestions = []);
                                },
                              )
                            : null),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            if (_suggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final item = _suggestions[idx];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: widget.accentColor,
                        size: 18,
                      ),
                      title: Text(
                        item.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        setState(() {
                          _pickedPoint = item.point;
                          _suggestions = [];
                        });
                        try {
                          _mapController.move(item.point, 15.5);
                        } catch (_) {}
                      },
                    );
                  },
                ),
              ),

            // Interactive FlutterMap
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _pickedPoint,
                      initialZoom: 15.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                      onTap: (_, latLng) {
                        setState(() => _pickedPoint = latLng);
                        try {
                          _mapController.move(
                            latLng,
                            _mapController.camera.zoom,
                          );
                        } catch (_) {}
                      },
                      onPositionChanged: (camera, hasGesture) {
                        if (hasGesture) {
                          setState(() => _pickedPoint = camera.center);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.ecommerce.umk.mobile',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pickedPoint,
                            width: 48,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.location_on_rounded,
                              color: Colors.red.shade600,
                              size: 46,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: const Text(
                        'Geser peta atau ketuk lokasi untuk menempatkan pin titik GPS secara presisi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom confirm bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Koordinat Terpilih',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${_pickedPoint.latitude.toStringAsFixed(6)}, ${_pickedPoint.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Salin Koordinat',
                        onPressed: () async {
                          final txt =
                              '${_pickedPoint.latitude.toStringAsFixed(6)}, ${_pickedPoint.longitude.toStringAsFixed(6)}';
                          await Clipboard.setData(ClipboardData(text: txt));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Koordinat disalin: $txt')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(_pickedPoint),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text(
                        'Gunakan Titik GPS Ini',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
