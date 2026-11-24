import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/core/utils/error_formatter.dart';
import 'package:mobile/features/assistant/models/assistance_log_model.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';

class AssistanceLogPage extends ConsumerWidget {
  final String? storeId;

  const AssistanceLogPage({super.key, this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(assistanceLogsProvider(storeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Aktivitas Pendampingan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(assistanceLogsProvider(storeId)),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat log aktivitas: ${formatUserFriendlyError(err)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(assistanceLogsProvider(storeId)),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum Ada Riwayat Aktivitas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Aktivitas pendampingan toko (kelola produk, stok, pesanan, dan pencatatan konten) akan tercatat otomatis di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(assistanceLogsProvider(storeId));
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildLogCard(logs[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogCard(AssistanceLogModel log) {
    final (Color badgeColor, IconData icon) = switch (log.actionType) {
      'engagement' => (Colors.pink.shade700, Icons.insights),
      'create_product' ||
      'update_product' => (Colors.teal.shade700, Icons.inventory),
      'update_stock' => (Colors.blue.shade700, Icons.edit_note),
      'ship_order' => (Colors.indigo.shade700, Icons.local_shipping),
      'create_content' ||
      'update_content' => (Colors.orange.shade700, Icons.article),
      _ => (Colors.purple.shade700, Icons.touch_app),
    };

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
}
