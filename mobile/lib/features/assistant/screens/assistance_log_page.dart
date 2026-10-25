import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/assistant/models/assistance_log_model.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';

class AssistanceLogPage extends ConsumerWidget {
  final String? storeId;

  const AssistanceLogPage({super.key, this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(assistanceLogsProvider(storeId));
    final assignedStoresAsync = ref.watch(assignedStoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CRUD Engagement & Pendampingan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(assistanceLogsProvider(storeId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final stores = assignedStoresAsync.asData?.value ?? [];
          _showEngagementFormDialog(
            context,
            ref,
            defaultStoreId: storeId ?? stores.firstOrNull?.storeId,
            stores: stores
                .map((s) => {'id': s.storeId, 'name': s.storeName})
                .toList(),
          );
        },
        icon: const Icon(Icons.add_chart),
        label: const Text('Catat Engagement'),
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text('Gagal memuat data engagement: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(assistanceLogsProvider(storeId)),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (logs) {
          final totalReach = logs.fold<int>(0, (s, l) => s + l.reachCount);
          final totalLikes = logs.fold<int>(0, (s, l) => s + l.likesCount);
          final totalComments = logs.fold<int>(
            0,
            (s, l) => s + l.commentsCount,
          );
          final totalShares = logs.fold<int>(0, (s, l) => s + l.sharesCount);
          final totalInquiries = logs.fold<int>(
            0,
            (s, l) => s + l.inquiriesCount,
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(assistanceLogsProvider(storeId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                _buildEngagementSummaryCard(
                  totalReach: totalReach,
                  totalLikes: totalLikes,
                  totalComments: totalComments,
                  totalShares: totalShares,
                  totalInquiries: totalInquiries,
                ),
                const SizedBox(height: 16),
                if (logs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(
                          Icons.insights_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum Ada Catatan Engagement / Pendampingan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Klik tombol "Catat Engagement" untuk menambahkan laporan jangkauan konten, interaksi medsos, atau aktivitas pendampingan UMK.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...logs.map(
                    (log) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildLogCard(
                        context,
                        ref,
                        log,
                        assignedStoresAsync.asData?.value
                                .map(
                                  (s) => {'id': s.storeId, 'name': s.storeName},
                                )
                                .toList() ??
                            [],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEngagementSummaryCard({
    required int totalReach,
    required int totalLikes,
    required int totalComments,
    required int totalShares,
    required int totalInquiries,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.purple.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Ringkasan Performa Engagement UMK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildMetricPill('Views / Reach', totalReach.toString()),
              _buildMetricPill('Likes', totalLikes.toString()),
              _buildMetricPill('Komentar', totalComments.toString()),
              _buildMetricPill('Share', totalShares.toString()),
              _buildMetricPill('Leads / Chat', totalInquiries.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(
    BuildContext context,
    WidgetRef ref,
    AssistanceLogModel log,
    List<Map<String, String>> stores,
  ) {
    Color badgeColor;
    IconData icon;

    switch (log.actionType) {
      case 'engagement':
        badgeColor = Colors.pink.shade700;
        icon = Icons.insights;
        break;
      case 'create_product':
      case 'update_product':
        badgeColor = Colors.teal.shade700;
        icon = Icons.inventory;
        break;
      case 'update_stock':
        badgeColor = Colors.blue.shade700;
        icon = Icons.edit_note;
        break;
      case 'ship_order':
        badgeColor = Colors.indigo.shade700;
        icon = Icons.local_shipping;
        break;
      case 'create_content':
      case 'update_content':
        badgeColor = Colors.orange.shade700;
        icon = Icons.article;
        break;
      default:
        badgeColor = Colors.purple.shade700;
        icon = Icons.touch_app;
        break;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: badgeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              log.actionTypeLabel,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (log.channel != null && log.channel!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                log.channel!.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Text(
                            DateFormatter.format(log.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        log.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (log.description != null &&
                          log.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          log.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEngagementFormDialog(
                        context,
                        ref,
                        existingLog: log,
                        defaultStoreId: log.storeId,
                        stores: stores,
                      );
                    } else if (value == 'delete') {
                      _confirmDeleteLog(context, ref, log);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (log.hasEngagementMetrics) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildSmallStat(
                      Icons.visibility_outlined,
                      '${log.reachCount} Reach',
                    ),
                    _buildSmallStat(
                      Icons.favorite_border,
                      '${log.likesCount} Likes',
                    ),
                    _buildSmallStat(
                      Icons.chat_bubble_outline,
                      '${log.commentsCount} Komentar',
                    ),
                    _buildSmallStat(
                      Icons.share_outlined,
                      '${log.sharesCount} Share',
                    ),
                    _buildSmallStat(
                      Icons.mark_chat_unread_outlined,
                      '${log.inquiriesCount} Leads',
                    ),
                  ],
                ),
              ),
            ],
            if (log.storeName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.storefront, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    log.storeName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.indigo.shade700),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  void _showEngagementFormDialog(
    BuildContext context,
    WidgetRef ref, {
    AssistanceLogModel? existingLog,
    String? defaultStoreId,
    required List<Map<String, String>> stores,
  }) {
    final titleCtrl = TextEditingController(text: existingLog?.title ?? '');
    final descCtrl = TextEditingController(
      text: existingLog?.description ?? '',
    );
    final reachCtrl = TextEditingController(
      text: (existingLog?.reachCount ?? 0).toString(),
    );
    final likesCtrl = TextEditingController(
      text: (existingLog?.likesCount ?? 0).toString(),
    );
    final commentsCtrl = TextEditingController(
      text: (existingLog?.commentsCount ?? 0).toString(),
    );
    final sharesCtrl = TextEditingController(
      text: (existingLog?.sharesCount ?? 0).toString(),
    );
    final inquiriesCtrl = TextEditingController(
      text: (existingLog?.inquiriesCount ?? 0).toString(),
    );

    String selectedStore =
        existingLog?.storeId ??
        defaultStoreId ??
        (stores.isNotEmpty ? stores.first['id']! : '');
    String selectedChannel = existingLog?.channel ?? 'instagram';
    String selectedActionType = existingLog?.actionType ?? 'engagement';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(
                existingLog == null
                    ? 'Tambah Catatan Engagement'
                    : 'Edit Catatan Engagement',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (existingLog == null && stores.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedStore.isNotEmpty
                            ? selectedStore
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Toko UMK Dampingan *',
                          border: OutlineInputBorder(),
                        ),
                        items: stores.map((s) {
                          return DropdownMenuItem(
                            value: s['id'],
                            child: Text(
                              s['name'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateDialog(() => selectedStore = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedChannel,
                      decoration: const InputDecoration(
                        labelText: 'Channel / Platform *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'instagram',
                          child: Text('Instagram'),
                        ),
                        DropdownMenuItem(
                          value: 'tiktok',
                          child: Text('TikTok'),
                        ),
                        DropdownMenuItem(
                          value: 'youtube',
                          child: Text('YouTube'),
                        ),
                        DropdownMenuItem(
                          value: 'whatsapp',
                          child: Text('WhatsApp Broadcast / Story'),
                        ),
                        DropdownMenuItem(
                          value: 'facebook',
                          child: Text('Facebook'),
                        ),
                        DropdownMenuItem(
                          value: 'marketplace',
                          child: Text('Feed Aplikasi UMK'),
                        ),
                        DropdownMenuItem(
                          value: 'offline',
                          child: Text('Bazar / Offline Pendampingan'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => selectedChannel = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Judul Kampanye / Aktivitas *',
                        hintText: 'Misal: Reels Promo Batik Pekalongan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: reachCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Views / Reach',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: likesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Likes',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Komentar',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: sharesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Shares',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: inquiriesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Leads / Chat Masuk / Konversi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Evaluasi Engagement',
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
                    if (titleCtrl.text.trim().isEmpty ||
                        selectedStore.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Judul dan Toko UMK wajib diisi.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogCtx);
                    try {
                      final service = ref.read(assistantServiceProvider);
                      final reach = int.tryParse(reachCtrl.text.trim()) ?? 0;
                      final likes = int.tryParse(likesCtrl.text.trim()) ?? 0;
                      final comments =
                          int.tryParse(commentsCtrl.text.trim()) ?? 0;
                      final shares = int.tryParse(sharesCtrl.text.trim()) ?? 0;
                      final inquiries =
                          int.tryParse(inquiriesCtrl.text.trim()) ?? 0;

                      if (existingLog == null) {
                        await service.createEngagementLog(
                          storeId: selectedStore,
                          title: titleCtrl.text.trim(),
                          actionType: selectedActionType,
                          description: descCtrl.text.trim(),
                          channel: selectedChannel,
                          reachCount: reach,
                          likesCount: likes,
                          commentsCount: comments,
                          sharesCount: shares,
                          inquiriesCount: inquiries,
                        );
                      } else {
                        await service.updateAssistanceLog(
                          logId: existingLog.id,
                          title: titleCtrl.text.trim(),
                          actionType: selectedActionType,
                          description: descCtrl.text.trim(),
                          channel: selectedChannel,
                          reachCount: reach,
                          likesCount: likes,
                          commentsCount: comments,
                          sharesCount: shares,
                          inquiriesCount: inquiries,
                        );
                      }

                      ref.invalidate(assistanceLogsProvider(storeId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              existingLog == null
                                  ? 'Data engagement berhasil ditambahkan.'
                                  : 'Data engagement berhasil diperbarui.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal menyimpan engagement: $e'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteLog(
    BuildContext context,
    WidgetRef ref,
    AssistanceLogModel log,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Catatan Engagement'),
        content: Text('Hapus catatan "${log.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(assistantServiceProvider)
                    .deleteAssistanceLog(log.id);
                ref.invalidate(assistanceLogsProvider(storeId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Catatan berhasil dihapus.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus: $e')),
                  );
                }
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
