import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/order/widgets/in_app_call_dialog.dart';

class LogisticsPartnerDashboardPage extends ConsumerStatefulWidget {
  final String partnerMode; // 'ekspedisi' (#13) or 'ojek' (#14)

  const LogisticsPartnerDashboardPage({
    super.key,
    required this.partnerMode,
  });

  @override
  ConsumerState<LogisticsPartnerDashboardPage> createState() =>
      _LogisticsPartnerDashboardPageState();
}

class _LogisticsPartnerDashboardPageState
    extends ConsumerState<LogisticsPartnerDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _orders = [];

  // Driver/Courier profile state
  String _driverName = '';
  String _driverPhone = '';
  String _vehiclePlate = '';

  @override
  void initState() {
    super.initState();
    // Ensure current user has proper logistics role in database
    supabase.rpc('become_logistics_partner', params: {'p_role': widget.partnerMode}).then((_) {
      if (mounted) ref.invalidate(appUserProvider);
    }).catchError((_) {});
    _tabController = TabController(length: 3, vsync: this);
    _initializePartner();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get isOjek => widget.partnerMode == 'ojek';
  String get partnerTitle => isOjek ? 'Portal Driver Ojek' : 'Portal Mitra Ekspedisi';

  Future<void> _initializePartner() async {
    final user = ref.read(appUserProvider).asData?.value;
    setState(() {
      _driverName = (user != null && user.fullName.isNotEmpty)
          ? user.fullName
          : (isOjek ? 'Budi Santoso (Driver)' : 'Mitra Ekspedisi Express');
      _driverPhone = user?.phone ?? '08123456789';
      _vehiclePlate = isOjek ? 'B 4123 ABC (Honda Vario)' : 'B 9876 XYZ (Truk Box)';
    });

    await _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await supabase
          .from('orders')
          .select('''
            id,
            order_number,
            status,
            tracking_status,
            payment_status,
            total_amount,
            courier_code,
            courier_name,
            courier_service_type,
            waybill_id,
            tracking_history,
            driver_name,
            driver_phone,
            driver_vehicle_plate,
            driver_latitude,
            driver_longitude,
            driver_messages,
            driver_last_updated,
            driver_id,
            biteship_order_id,
            shipping_name,
            shipping_address,
            shipping_phone,
            shipping_latitude,
            shipping_longitude,
            created_at,
            stores:store_id (
              name,
              address
            )
          ''')
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(response as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // Filter orders by active tab
  List<Map<String, dynamic>> _getFilteredOrders(int tabIndex) {
    final currentUserId = supabase.auth.currentUser?.id;

    // Helper: Is order intended for current partner mode (Ojek vs Ekspedisi)
    bool isMatchingCourier(Map<String, dynamic> o) {
      final code = (o['courier_code'] ?? '').toString().toLowerCase();
      final hasBiteship = o['biteship_order_id'] != null;

      // Never show external Biteship-managed orders in local driver portal
      if (hasBiteship || code == 'jne' || code == 'sicepat' || code == 'jnt' || code == 'anteraja') {
        return false;
      }

      if (isOjek) {
        // Ojek lokal: ojek, ojek_lokal, instant_lokal, or instant/same_day service
        final sType = (o['courier_service_type'] ?? '').toString().toLowerCase();
        return code == 'ojek' || code == 'ojek_lokal' || code == 'instant_lokal' || sType == 'instant' || sType == 'same_day';
      } else {
        // Ekspedisi / armada toko
        return code == 'ekspedisi' || code == 'ekspedisi_lokal' || code == 'kurir_toko' || code == 'manual' || code.isEmpty;
      }
    }

    if (tabIndex == 0) {
      // Tab 0: Pending / Unassigned / Ready to pickup (Local orders without driver)
      return _orders.where((o) {
        if (!isMatchingCourier(o)) return false;
        final dStatus = (o['tracking_status'] ?? o['status'] ?? '').toString();
        final hasDriver = o['driver_id'] != null || (o['driver_name'] != null && o['driver_name'].toString().isNotEmpty);
        return !hasDriver && (dStatus == 'ready_to_ship' || dStatus == 'pending' || dStatus == 'processing' || dStatus == 'allocated');
      }).toList();
    } else if (tabIndex == 1) {
      // Tab 1: Active / On Delivery (Claimed by current driver)
      return _orders.where((o) {
        final orderDriverId = o['driver_id']?.toString();
        final isMine = currentUserId != null && (orderDriverId == currentUserId || (orderDriverId == null && o['driver_name'] == _driverName));
        if (!isMine) return false;

        final dStatus = (o['tracking_status'] ?? o['status'] ?? '').toString();
        return dStatus == 'picking_up' ||
            dStatus == 'picked' ||
            dStatus == 'dropping_off' ||
            dStatus == 'on_delivery';
      }).toList();
    } else {
      // Tab 2: Completed / Cancelled (Finished by current driver)
      return _orders.where((o) {
        final orderDriverId = o['driver_id']?.toString();
        final isMine = currentUserId != null && (orderDriverId == currentUserId || (orderDriverId == null && o['driver_name'] == _driverName));
        if (!isMine) return false;

        final dStatus = (o['tracking_status'] ?? o['status'] ?? '').toString();
        return dStatus == 'delivered' ||
            dStatus == 'completed' ||
            dStatus == 'cancelled';
      }).toList();
    }
  }

  // --- ACTIONS ---

  // 1. Approval Pengiriman (Atomic Claim & Tugaskan Diri)
  Future<void> _approveShipment(Map<String, dynamic> order) async {
    final orderId = order['id'];

    try {
      await supabase.rpc('claim_logistics_order', params: {
        'p_order_id': orderId,
        'p_driver_name': _driverName,
        'p_driver_phone': _driverPhone,
        'p_vehicle_plate': _vehiclePlate,
        'p_latitude': isOjek ? -6.2088 : null,
        'p_longitude': isOjek ? 106.8456 : null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Pesanan berhasil diterima untuk ${isOjek ? "penjemputan" : "alokasi armada"}!"),
          backgroundColor: Colors.green.shade700,
        ),
      );
      _fetchOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menerima pesanan: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // 2. Update Resi Manual (Ekspedisi #13)
  void _showWaybillInputDialog(Map<String, dynamic> order) {
    final controller = TextEditingController(text: order['waybill_id'] ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Input No Resi Manual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan nomor resi fisik ekspedisi untuk pelacakan pembeli:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Nomor Resi / AWB',
                  hintText: 'Misal: EXP-2026-889901',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code_2),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newWaybill = controller.text.trim();
                if (newWaybill.isEmpty) return;

                Navigator.pop(dialogCtx);
                try {
                  await supabase.rpc('update_logistics_shipment', params: {
                    'p_order_id': order['id'],
                    'p_status': order['tracking_status'] ?? 'allocated',
                    'p_waybill_id': newWaybill,
                    'p_note': 'No resi diperbarui menjadi: $newWaybill',
                  });

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nomor resi berhasil disimpan!')),
                  );
                  _fetchOrders();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menyimpan resi: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Simpan Resi'),
            ),
          ],
        );
      },
    );
  }

  // 3. Update Delivery Status (Ekspedisi / Ojek)
  void _showUpdateStatusDialog(Map<String, dynamic> order) {
    String selectedStatus = (order['tracking_status'] ?? 'allocated').toString();
    final noteController = TextEditingController();

    final statusOptions = isOjek
        ? [
            {'value': 'picking_up', 'label': 'Menuju Toko / Lokasi Pickup'},
            {'value': 'picked', 'label': 'Pesanan Diambil (Menuju Pembeli)'},
            {'value': 'on_delivery', 'label': 'Dalam Perjalanan Pengantaran'},
            {'value': 'delivered', 'label': 'Tiba & Diserahkan (Selesai)'},
          ]
        : [
            {'value': 'allocated', 'label': 'Dialokasikan ke Kurir Ekspedisi'},
            {'value': 'picking_up', 'label': 'Penjemputan ke Penjual / Hub'},
            {'value': 'picked', 'label': 'Paket Masuk Hub Ekspedisi'},
            {'value': 'dropping_off', 'label': 'Transit Antar Hub'},
            {'value': 'on_delivery', 'label': 'Kurir Mengantar ke Alamat'},
            {'value': 'delivered', 'label': 'Paket Diterima Pembeli (Selesai)'},
          ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Update Status ${isOjek ? "Ojek" : "Ekspedisi"}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Status Pengiriman',
                        border: OutlineInputBorder(),
                      ),
                      items: statusOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt['value']!,
                          child: Text(opt['label']!, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedStatus = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Rute / Keterangan',
                        hintText: 'Misal: Paket telah disortir di Hub Jakarta Selatan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    try {
                      await supabase.rpc('update_logistics_shipment', params: {
                        'p_order_id': order['id'],
                        'p_status': selectedStatus,
                        'p_note': noteController.text.trim().isNotEmpty
                            ? noteController.text.trim()
                            : 'Status diubah ke $selectedStatus',
                      });

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Status pengiriman berhasil diperbarui!')),
                      );
                      _fetchOrders();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal update status: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Perbarui'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 4. Update Live GPS Simulation (Ojek #14 & Ekspedisi)
  void _showUpdateGpsDialog(Map<String, dynamic> order) {
    double currentLat = (order['driver_latitude'] as num?)?.toDouble() ?? -6.2088;
    double currentLng = (order['driver_longitude'] as num?)?.toDouble() ?? 106.8456;

    final latController = TextEditingController(text: currentLat.toStringAsFixed(6));
    final lngController = TextEditingController(text: currentLng.toStringAsFixed(6));

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Update Koordinat GPS Driver'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Perbarui posisi real-time pengemudi agar rute terlihat dinamis pada aplikasi Pembeli:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: latController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lngController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    label: const Text('+0.005 Lat (Maju)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      final val = (double.tryParse(latController.text) ?? -6.2088) + 0.005;
                      latController.text = val.toStringAsFixed(6);
                    },
                  ),
                  ActionChip(
                    label: const Text('+0.005 Lng (Belok)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      final val = (double.tryParse(lngController.text) ?? 106.8456) + 0.005;
                      lngController.text = val.toStringAsFixed(6);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final lat = double.tryParse(latController.text);
                final lng = double.tryParse(lngController.text);
                if (lat == null || lng == null) return;

                Navigator.pop(dialogCtx);
                try {
                  await supabase.rpc('update_logistics_shipment', params: {
                    'p_order_id': order['id'],
                    'p_status': order['tracking_status'] ?? 'on_delivery',
                    'p_latitude': lat,
                    'p_longitude': lng,
                    'p_note': 'Posisi GPS diperbarui ($lat, $lng)',
                  });

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lokasi GPS pengemudi berhasil dikirim ke Pembeli!')),
                  );
                  _fetchOrders();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal update GPS: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Kirim GPS'),
            ),
          ],
        );
      },
    );
  }

  // 5. CRUD Pembatalan Pengiriman Sisi Ekspedisi / Ojek (#13 req 4)
  void _showCancelShipmentDialog(Map<String, dynamic> order) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Batalkan Pengiriman (Logistik)', style: TextStyle(color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pemberitahuan: Pembatalan dari sisi logistik akan mencatat riwayat kendala operasional dan mengembalikan status ke sistem.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Alasan Pembatalan Kendala *',
                  hintText: 'Misal: Akses jalan banjir / Kendaraan mengalami kerusakan teknis',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Kembali'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Harap masukkan alasan kendala pembatalan')),
                  );
                  return;
                }

                Navigator.pop(dialogCtx);
                try {
                  await supabase.rpc('cancel_logistics_shipment', params: {
                    'p_order_id': order['id'],
                    'p_reason': reason,
                  });

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pengiriman berhasil dibatalkan oleh logistik')),
                  );
                  _fetchOrders();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal membatalkan pengiriman: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Konfirmasi Batal', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 6. Hubungi Pembeli (In-App Call #10 & Realtime Chat #11)
  void _openInAppCall(Map<String, dynamic> order) {
    final buyerName = order['shipping_name'] ?? 'Pembeli';
    final buyerPhone = order['shipping_phone'] ?? '08123456789';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (callContext) => InAppCallDialog(
        orderId: order['id'],
        orderNumber: order['order_number'] ?? order['id'].toString().substring(0, 8),
        remotePartyName: buyerName,
        remotePartyPhone: buyerPhone,
        callerRole: isOjek ? 'ojek' : 'ekspedisi',
      ),
    );
  }

  void _openInAppChat(Map<String, dynamic> order) {
    final buyerName = order['shipping_name'] ?? 'Pembeli';
    var messages = List<Map<String, dynamic>>.from(
      order['driver_messages'] as List? ?? [],
    );
    final textController = TextEditingController();
    RealtimeChannel? chatChannel;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        var subscribed = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (!subscribed) {
              subscribed = true;
              supabase
                  .from('orders')
                  .select('driver_messages')
                  .eq('id', order['id'])
                  .maybeSingle()
                  .then((val) {
                if (val != null && val['driver_messages'] is List && ctx.mounted) {
                  setModalState(() {
                    messages = (val['driver_messages'] as List)
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();
                  });
                }
              });

              chatChannel = supabase
                  .channel('driver_chat_ojek:order_${order['id']}')
                  .onPostgresChanges(
                    event: PostgresChangeEvent.update,
                    schema: 'public',
                    table: 'orders',
                    filter: PostgresChangeFilter(
                      type: PostgresChangeFilterType.eq,
                      column: 'id',
                      value: order['id'],
                    ),
                    callback: (payload) {
                      final raw = payload.newRecord['driver_messages'];
                      if (raw is List && ctx.mounted) {
                        setModalState(() {
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

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SizedBox(
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: const Icon(Icons.person, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chat Pembeli: $buyerName',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Pesanan #${(order['order_number'] ?? order['id']).toString().substring(0, 8)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: messages.isEmpty
                          ? Center(
                              child: Text(
                                'Belum ada percakapan dengan pembeli.\nKirim pesan untuk konfirmasi titik antar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              itemCount: messages.length,
                              itemBuilder: (context, idx) {
                                final msg = messages[idx];
                                final isMe = msg['sender_role'] == (isOjek ? 'ojek' : 'ekspedisi') ||
                                    msg['sender_role'] == 'driver';
                                return Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isMe ? AppColors.primary : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg['message'] ?? '',
                                          style: TextStyle(
                                            color: isMe ? Colors.white : Colors.black87,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          msg['sender_name'] ?? (isMe ? 'Saya' : buyerName),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe ? Colors.white70 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: textController,
                              decoration: const InputDecoration(
                                hintText: 'Tulis pesan konfirmasi ke pembeli...',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send, color: AppColors.primary),
                            onPressed: () async {
                              final text = textController.text.trim();
                              if (text.isEmpty) return;

                              final newMsg = {
                                'sender_role': isOjek ? 'ojek' : 'ekspedisi',
                                'sender_name': _driverName,
                                'message': text,
                                'sent_at': DateTime.now().toIso8601String(),
                              };

                              setModalState(() {
                                messages.add(newMsg);
                              });
                              textController.clear();

                              try {
                                final res = await supabase.rpc('append_order_driver_message', params: {
                                  'p_order_id': order['id'],
                                  'p_sender_role': isOjek ? 'ojek' : 'ekspedisi',
                                  'p_sender_name': _driverName,
                                  'p_message': text,
                                });
                                if (res is List && ctx.mounted) {
                                  setModalState(() {
                                    messages = res
                                        .whereType<Map>()
                                        .map((e) => Map<String, dynamic>.from(e))
                                        .toList();
                                  });
                                }
                                _fetchOrders();
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Gagal mengirim pesan: $e')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      chatChannel?.unsubscribe();
    });
  }

  // --- UI BUILDERS ---

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOjek ? Colors.deepOrange.shade600 : Colors.indigo.shade700,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                child: Icon(
                  isOjek ? Icons.two_wheeler : Icons.local_shipping,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _driverName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_driverPhone • $_vehiclePlate',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.white),
                tooltip: 'Ubah Data Armada/Driver',
                onPressed: () => _showEditProfileDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  isOjek
                      ? 'Status: Siap Terima Pesanan Instan (Online)'
                      : 'Status: Hub Logistik Ekspedisi Aktif',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _driverName);
    final phoneCtrl = TextEditingController(text: _driverPhone);
    final vehicleCtrl = TextEditingController(text: _vehiclePlate);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Edit Data ${isOjek ? "Driver Ojek" : "Mitra Ekspedisi"}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: isOjek ? 'Nama Driver' : 'Nama Ekspedisi/Kurir',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp / HP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: vehicleCtrl,
              decoration: InputDecoration(
                labelText: isOjek ? 'Kendaraan & Plat Nomor' : 'Nama Armada / Truk',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _driverName = nameCtrl.text.trim();
                _driverPhone = phoneCtrl.text.trim();
                _vehiclePlate = vehicleCtrl.text.trim();
              });
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil pengiriman berhasil diperbarui')),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int tabIndex) {
    final orderId = (order['order_number'] ?? order['id']).toString();
    final dStatus = (order['tracking_status'] ?? order['status'] ?? 'pending').toString();
    final storeName = (order['stores'] != null && order['stores']['name'] != null)
        ? order['stores']['name']
        : 'Toko UMK Mitra';
    final recipient = order['shipping_name'] ?? 'Pembeli';
    final address = order['shipping_address'] ?? 'Alamat pengantaran';
    final courier = (order['courier_name'] ?? (isOjek ? 'Ojek Lokal' : 'Ekspedisi')).toString();
    final waybill = order['waybill_id'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Order ID & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '#${orderId.substring(0, orderId.length > 12 ? 12 : orderId.length)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(dStatus).withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusLabel(dStatus),
                    style: TextStyle(
                      color: _getStatusColor(dStatus),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Row 2: Rute Pickup & Dropoff
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.store, color: AppColors.primary, size: 20),
                    Container(height: 24, width: 2, color: Colors.grey.shade300),
                    const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        'Pickup: Toko UMK',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        recipient,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 3: Detail Kurir & No Resi
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(isOjek ? Icons.motorcycle : Icons.inventory_2_outlined,
                      size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Layanan: $courier ${waybill != null ? "• Resi: $waybill" : ""}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (!isOjek)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showWaybillInputDialog(order),
                      child: Text(waybill == null ? 'Input Resi' : 'Ubah Resi',
                          style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Actions per status
            if (tabIndex == 0) ...[
              // Approval section
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Tolak'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Penugasan ditolak')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOjek ? Colors.deepOrange : AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(isOjek ? 'Terima & Jemput' : 'Approve & Jadwalkan'),
                      onPressed: () => _approveShipment(order),
                    ),
                  ),
                ],
              ),
            ] else if (tabIndex == 1) ...[
              // Active Delivery Actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Update Status'),
                    onPressed: () => _showUpdateStatusDialog(order),
                  ),
                  if (isOjek) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.gps_fixed, size: 16),
                      label: const Text('Update GPS'),
                      onPressed: () => _showUpdateGpsDialog(order),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.phone, size: 16, color: Colors.green),
                      label: const Text('Call Pembeli'),
                      onPressed: () => _openInAppCall(order),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.chat, size: 16, color: Colors.blue),
                      label: const Text('Chat Pembeli'),
                      onPressed: () => _openInAppChat(order),
                    ),
                  ],
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Kendala / Batal'),
                    onPressed: () => _showCancelShipmentDialog(order),
                  ),
                ],
              ),
            ] else ...[
              // Completed or Cancelled
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Riwayat Selesai',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  TextButton(
                    onPressed: () => context.push('/orders/${order['id']}'),
                    child: const Text('Lihat Detail', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'on_delivery':
      case 'picked':
        return Colors.blue;
      case 'picking_up':
      case 'allocated':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey.shade700;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'allocated':
        return 'Dialokasikan';
      case 'picking_up':
        return 'Penjemputan';
      case 'picked':
        return 'Paket Diambil';
      case 'dropping_off':
        return 'Transit Hub';
      case 'on_delivery':
        return 'Dalam Pengantaran';
      case 'delivered':
        return 'Terkirim';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(partnerTitle),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Data',
            onPressed: _fetchOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Penugasan Baru'),
            Tab(text: 'Sedang Aktif'),
            Tab(text: 'Riwayat Selesai'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchOrders,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Pemberitahuan: $_errorMessage',
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  SizedBox(
                    height: 520,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabList(0),
                        _buildTabList(1),
                        _buildTabList(2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTabList(int tabIndex) {
    final list = _getFilteredOrders(tabIndex);
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tabIndex == 0
                  ? Icons.inbox
                  : tabIndex == 1
                      ? Icons.motorcycle
                      : Icons.task_alt,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              tabIndex == 0
                  ? 'Tidak ada penugasan baru yang menunggu approval.'
                  : tabIndex == 1
                      ? 'Tidak ada pengiriman yang sedang berjalan aktif.'
                      : 'Belum ada riwayat pengiriman selesai.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (ctx, idx) => _buildOrderCard(list[idx], tabIndex),
    );
  }
}
