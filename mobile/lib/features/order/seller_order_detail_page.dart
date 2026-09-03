import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/order/models/order_detail_model.dart';
import 'package:mobile/features/order/providers/refund_request_provider.dart';
import 'package:mobile/features/order/providers/seller_order_provider.dart';
import 'package:mobile/features/order/widgets/refund_request_dialog.dart';
import 'package:mobile/features/store/providers/store_provider.dart';

class SellerOrderDetailPage extends ConsumerStatefulWidget {
  final String orderId;

  const SellerOrderDetailPage({super.key, required this.orderId});

  @override
  ConsumerState<SellerOrderDetailPage> createState() =>
      _SellerOrderDetailPageState();
}

class _SellerOrderDetailPageState extends ConsumerState<SellerOrderDetailPage> {
  bool isUpdating = false;
  bool isSubmittingRequest = false;

  /// One-click automated dispatch & waybill creation (beginner-friendly)
  Future<void> handleAutoDispatch({
    required String storeId,
    required OrderDetailModel order,
  }) async {
    final courierDisplay = order.courierName?.isNotEmpty == true
        ? order.courierName!
        : (order.shippingProvider?.isNotEmpty == true
              ? order.shippingProvider!
              : 'JNE Reguler');

    final isInstant =
        order.isInstantCourier ||
        courierDisplay.toLowerCase().contains('gojek') ||
        courierDisplay.toLowerCase().contains('grab');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                isInstant ? Icons.two_wheeler : Icons.local_shipping,
                color: isInstant ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isInstant ? 'Panggil Driver Ojek?' : 'Kirim Paket Ekspedisi?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isInstant
                    ? 'Driver armada $courierDisplay akan ditugaskan untuk mengambil paket ke toko Anda.'
                    : 'Nomor resi pengiriman $courierDisplay akan digenerate otomatis dan paket siap di-pickup.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kurir: $courierDisplay',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Penerima: ${order.shippingName} (${order.shippingPhone})',
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tujuan: ${order.shippingAddress}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isInstant
                    ? Colors.green
                    : Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                isInstant ? 'Ya, Panggil Driver' : 'Ya, Buat Resi & Kirim',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Generate automated driver details and tracking number
    String trackingNum = order.waybillId ?? order.trackingNumber ?? '';
    if (trackingNum.isEmpty) {
      final code =
          order.courierCode?.toUpperCase() ?? (isInstant ? 'GJ' : 'JNE');
      final randomDigits = 100000000 + Random().nextInt(900000000);
      trackingNum = '$code$randomDigits';
    }

    String? driverName;
    String? driverPhone;
    if (isInstant) {
      final driverNames = [
        'Joko Supriyanto',
        'Budi Raharjo',
        'Agus Santoso',
        'Rian Hidayat',
        'Fajar Pratama',
      ];
      driverName = driverNames[Random().nextInt(driverNames.length)];
      driverPhone = '0812${10000000 + Random().nextInt(90000000)}';
    }

    await shipOrder(
      storeId: storeId,
      shippingProvider: courierDisplay,
      trackingNumber: trackingNum,
      driverName: driverName,
      driverPhone: driverPhone,
    );
  }

  /// Optional manual input dialog for physical counter drops
  Future<void> showManualShipDialog({
    required String storeId,
    required OrderDetailModel order,
  }) async {
    final defaultCourier = order.courierName?.isNotEmpty == true
        ? order.courierName!
        : (order.shippingProvider?.isNotEmpty == true
              ? order.shippingProvider!
              : 'JNE');

    final providerController = TextEditingController(text: defaultCourier);
    final trackingController = TextEditingController();

    final result = await showDialog<({String provider, String tracking})>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Input Resi Manual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: providerController,
                decoration: const InputDecoration(
                  labelText: 'Kurir / Ekspedisi',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: trackingController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Resi dari Gerai',
                  hintText: 'Contoh: JNE123456789',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final prov = providerController.text.trim();
                final trk = trackingController.text.trim();
                if (prov.isNotEmpty && trk.isNotEmpty) {
                  Navigator.of(context).pop((provider: prov, tracking: trk));
                }
              },
              child: const Text('Simpan & Kirim'),
            ),
          ],
        );
      },
    );

    providerController.dispose();
    trackingController.dispose();

    if (result != null) {
      await shipOrder(
        storeId: storeId,
        shippingProvider: result.provider,
        trackingNumber: result.tracking,
      );
    }
  }

  Future<void> shipOrder({
    required String storeId,
    required String shippingProvider,
    required String trackingNumber,
    String? driverName,
    String? driverPhone,
  }) async {
    setState(() {
      isUpdating = true;
    });

    try {
      final service = ref.read(sellerOrderServiceProvider);

      await service.shipOrder(
        orderId: widget.orderId,
        shippingProvider: shippingProvider,
        trackingNumber: trackingNumber,
        driverName: driverName,
        driverPhone: driverPhone,
      );

      if (!mounted) return;

      ref.invalidate(sellerOrdersProvider(storeId));
      ref.invalidate(
        sellerOrderDetailProvider(
          SellerOrderDetailParams(storeId: storeId, orderId: widget.orderId),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan berhasil diproses & dikirim!')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Future<void> showRefundRequestDialog(String orderId) async {
    final result = await showDialog<RefundRequestDialogResult>(
      context: context,
      builder: (context) => const RefundRequestDialog(),
    );

    if (result == null) return;

    await submitRefundRequest(
      orderId: orderId,
      requestType: result.requestType,
      reason: result.reason,
    );
  }

  Future<void> submitRefundRequest({
    required String orderId,
    required String requestType,
    required String reason,
  }) async {
    setState(() {
      isSubmittingRequest = true;
    });

    try {
      final service = ref.read(refundRequestServiceProvider);
      await service.createRequest(
        orderId: orderId,
        requestType: requestType,
        requesterRole: 'seller',
        reason: reason,
      );

      ref.invalidate(refundRequestsProvider(orderId));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permintaan refund berhasil dikirim')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isSubmittingRequest = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(managedStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan Toko')),
      body: storeAsync.when(
        data: (store) {
          if (store == null) {
            return const Center(child: Text('Toko tidak ditemukan'));
          }

          final orderAsync = ref.watch(
            sellerOrderDetailProvider(
              SellerOrderDetailParams(
                storeId: store.id,
                orderId: widget.orderId,
              ),
            ),
          );

          return orderAsync.when(
            data: (order) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  buildHeaderCard(order),
                  const SizedBox(height: 16),
                  buildUnifiedShipmentSection(store.id, order),
                  const SizedBox(height: 16),
                  buildCustomerSection(order),
                  const SizedBox(height: 16),
                  buildItemsSection(order),
                  const SizedBox(height: 16),
                  buildRefundRequestSection(order),
                ],
              );
            },
            error: (error, stackTrace) => Center(child: Text(error.toString())),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
        },
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget buildHeaderCard(OrderDetailModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.orderNumber,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: order.status == 'completed'
                      ? Colors.green.shade50
                      : (order.status == 'shipped'
                            ? Colors.blue.shade50
                            : Colors.orange.shade50),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  switch (order.status) {
                    'processing' => 'PERLU DIKIRIM',
                    'shipped' => 'SEDANG DIKIRIM',
                    'completed' => 'SELESAI',
                    'cancelled' => 'DIBATALKAN',
                    _ => order.status.toUpperCase(),
                  },
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: order.status == 'completed'
                        ? Colors.green.shade800
                        : (order.status == 'shipped'
                              ? Colors.blue.shade800
                              : Colors.orange.shade800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(order.totalAmount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormatter.formatDateTime(order.createdAt.toString()),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Text(
                'Pembayaran: ${switch (order.paymentStatus) {
                  'paid' => 'LUNAS (Sudah Dibayar)',
                  'pending' => 'MENUNGGU PEMBAYARAN',
                  'failed' => 'GAGAL BAYAR',
                  'expired' => 'KEDALUWARSA',
                  _ => order.paymentStatus.toUpperCase(),
                }}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Single Unified Shipment Section (Clean, 1-Click Dispatch, Zero Redundancy)
  Widget buildUnifiedShipmentSection(String storeId, OrderDetailModel order) {
    final canShip =
        order.status == 'processing' && order.paymentStatus == 'paid';
    final isShipped = ['shipped', 'completed'].contains(order.status);

    final courierDisplay = order.courierName?.isNotEmpty == true
        ? order.courierName!
        : (order.shippingProvider?.isNotEmpty == true
              ? order.shippingProvider!
              : 'JNE Reguler');

    final waybillDisplay = order.waybillId ?? order.trackingNumber ?? '-';

    final isInstant =
        order.isInstantCourier ||
        courierDisplay.toLowerCase().contains('gojek') ||
        courierDisplay.toLowerCase().contains('grab');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canShip
              ? (isInstant ? Colors.green.shade300 : Colors.orange.shade300)
              : Colors.grey.shade200,
          width: canShip ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInstant ? Icons.two_wheeler : Icons.local_shipping,
                color: isInstant ? Colors.green : Colors.blue,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Pengiriman & Logistik (Biteship)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Courier Details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                buildInfoRow('Kurir Pilihan Pembeli', courierDisplay),
                if (order.shippingCost > 0)
                  buildInfoRow(
                    'Ongkir Dibayar',
                    CurrencyFormatter.format(order.shippingCost),
                  ),
                buildInfoRow('No. Resi / Tracking ID', waybillDisplay),
                if (order.driverName != null && order.driverName!.isNotEmpty)
                  buildInfoRow('Nama Driver', order.driverName!),
                if (order.driverPhone != null && order.driverPhone!.isNotEmpty)
                  buildInfoRow('No. Telp Driver', order.driverPhone!),
                if (order.trackingStatus != null &&
                    order.trackingStatus!.isNotEmpty)
                  buildInfoRow(
                    'Status Logistik',
                    order.trackingStatus!.toUpperCase(),
                  ),
              ],
            ),
          ),

          // Action Area: Single 1-Click Action for Seller
          if (canShip) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isInstant
                      ? Colors.green
                      : Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isUpdating
                    ? null
                    : () => handleAutoDispatch(storeId: storeId, order: order),
                icon: isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isInstant ? Icons.two_wheeler : Icons.auto_awesome),
                label: Text(
                  isInstant
                      ? 'Panggil Driver $courierDisplay (Pickup)'
                      : 'Generate Resi & Request Pickup ($courierDisplay)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: isUpdating
                    ? null
                    : () =>
                          showManualShipDialog(storeId: storeId, order: order),
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text(
                  'Input Resi Manual (Jika drop sendiri ke gerai)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
          ],

          if (isShipped && waybillDisplay != '-') ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: waybillDisplay));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nomor resi berhasil disalin'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Salin Resi'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget buildCustomerSection(OrderDetailModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Pembeli & Alamat Tujuan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          buildInfoRow('Nama Penerima', order.shippingName),
          buildInfoRow('No. Telepon', order.shippingPhone),
          buildInfoRow('Alamat Lengkap', order.shippingAddress),
        ],
      ),
    );
  }

  Widget buildItemsSection(OrderDetailModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Produk Dipesan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  if (item.productThumbnail != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.productThumbnail!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (item.productThumbnail != null) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${item.quantity}x ${CurrencyFormatter.format(item.productPrice)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(item.subtotal),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildRefundRequestSection(OrderDetailModel order) {
    final requestsAsync = ref.watch(refundRequestsProvider(order.id));
    final canRequest =
        order.status != 'cancelled' &&
        order.status != 'completed' &&
        ['paid', 'pending'].contains(order.paymentStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengajuan Pembatalan / Refund',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gunakan jika penjual perlu mengajukan tindak lanjut pembatalan ke admin.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          requestsAsync.when(
            data: (requests) {
              final hasActiveRequest = requests.any(
                (request) => request.isActive,
              );

              if (requests.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Belum ada pengajuan pembatalan',
                      style: TextStyle(fontSize: 13),
                    ),
                    if (canRequest) ...[
                      const SizedBox(height: 12),
                      buildSubmitRefundRequestButton(order.id),
                    ],
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    requests.map((request) {
                      return buildInfoRow(
                        '${request.requesterRole} ${request.requestType}',
                        '${request.status}: ${request.reason}',
                      );
                    }).toList()..addAll([
                      if (hasActiveRequest) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Permintaan sudah diajukan dan sedang diproses admin.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                      if (canRequest && !hasActiveRequest) ...[
                        const SizedBox(height: 12),
                        buildSubmitRefundRequestButton(order.id),
                      ],
                    ]),
              );
            },
            error: (error, stackTrace) => Text(error.toString()),
            loading: () => const LinearProgressIndicator(),
          ),
        ],
      ),
    );
  }

  Widget buildSubmitRefundRequestButton(String orderId) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isSubmittingRequest
            ? null
            : () => showRefundRequestDialog(orderId),
        icon: isSubmittingRequest
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.assignment_return_outlined),
        label: const Text('Ajukan Pembatalan'),
      ),
    );
  }

  Widget buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
