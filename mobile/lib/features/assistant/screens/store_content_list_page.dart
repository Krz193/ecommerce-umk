import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/assistant/models/store_content_model.dart';
import 'package:mobile/features/assistant/providers/assistant_providers.dart';
import 'package:mobile/features/store/providers/store_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher/url_launcher.dart';

class StoreContentListPage extends ConsumerWidget {
  final String storeId;
  final String? storeName;

  const StoreContentListPage({
    super.key,
    required this.storeId,
    this.storeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myStore = ref.watch(myStoreProvider).asData?.value;
    final selectedStore = ref.watch(selectedStoreProvider);
    final assignedStores = ref.watch(assignedStoresProvider).asData?.value;

    final effectiveStoreId = storeId.trim().isNotEmpty
        ? storeId.trim()
        : (selectedStore?.storeId ??
            myStore?.id ??
            assignedStores?.firstOrNull?.storeId ??
            '');

    final effectiveStoreName = (storeName != null && storeName!.trim().isNotEmpty)
        ? storeName!.trim()
        : (selectedStore?.storeName ??
            myStore?.name ??
            assignedStores?.firstOrNull?.storeName);

    final titleText = (effectiveStoreName != null && effectiveStoreName.isNotEmpty)
        ? 'Konten $effectiveStoreName'
        : 'Konten UMK';

    if (effectiveStoreId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(titleText),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Toko Belum Ditemukan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tidak ada data toko yang dipilih atau ditugaskan untuk melihat konten.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final contentsAsync = ref.watch(storeContentsProvider(effectiveStoreId));

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(storeContentsProvider(effectiveStoreId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push<bool>(
            '/assistant/contents/create?storeId=$effectiveStoreId',
          );
          if (result == true) {
            ref.invalidate(storeContentsProvider(effectiveStoreId));
            ref.invalidate(assistanceLogsProvider(effectiveStoreId));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Buat Konten'),
      ),
      body: contentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text('Gagal memuat konten: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(storeContentsProvider(effectiveStoreId)),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (contents) {
          if (contents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum Ada Konten UMK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Buat banner promosi, kisah produk, atau konten media sosial (Video, Gambar, Reels) untuk membantu penjualan toko UMK ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await context.push<bool>(
                        '/assistant/contents/create?storeId=$effectiveStoreId',
                      );
                      if (result == true) {
                        ref.invalidate(storeContentsProvider(effectiveStoreId));
                        ref.invalidate(assistanceLogsProvider(effectiveStoreId));
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Konten Pertama'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(storeContentsProvider(effectiveStoreId));
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: contents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = contents[index];
                return _buildContentCard(context, ref, item, effectiveStoreId);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildContentCard(
    BuildContext context,
    WidgetRef ref,
    StoreContentModel item,
    String currentStoreId,
  ) {
    final hasExternalUrl =
        item.externalUrl != null && item.externalUrl!.trim().isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await context.push<bool>(
            '/assistant/contents/edit/${item.id}?storeId=$currentStoreId',
            extra: item,
          );
          if (result == true) {
            ref.invalidate(storeContentsProvider(currentStoreId));
            ref.invalidate(assistanceLogsProvider(storeId));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.contentTypeLabel,
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.mediaFormatLabel,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.socialPlatform != null &&
                            item.socialPlatform!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.socialPlatformLabel,
                              style: TextStyle(
                                color: Colors.purple.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.isActive
                              ? Colors.teal.shade50
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: item.isActive
                                ? Colors.teal.shade300
                                : Colors.grey.shade400,
                          ),
                        ),
                        child: Text(
                          item.isActive ? 'Aktif' : 'Non-Aktif',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item.isActive
                                ? Colors.teal.shade800
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.red,
                        ),
                        onPressed: () => _confirmDelete(context, ref, item, currentStoreId),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (item.body != null && item.body!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.body!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
              if (hasExternalUrl) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () async {
                        final uri = Uri.tryParse(item.externalUrl!.trim());
                        if (uri != null) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 15),
                      label: Text(
                        'Buka di ${item.socialPlatformLabel}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: item.externalUrl!.trim()),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link konten berhasil disalin!'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_outlined, size: 15),
                      label: const Text(
                        'Salin Link',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dibuat: ${DateFormatter.format(item.createdAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Edit >',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    StoreContentModel item,
    String currentStoreId,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Konten UMK'),
        content: Text(
          'Apakah Anda yakin ingin menghapus konten "${item.title}"?',
        ),
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
                final service = ref.read(assistantServiceProvider);
                await service.deleteStoreContent(
                  contentId: item.id,
                  storeId: currentStoreId,
                  title: item.title,
                );
                ref.invalidate(storeContentsProvider(storeId));
                ref.invalidate(assistanceLogsProvider(storeId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Konten berhasil dihapus')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus konten: $e')),
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
