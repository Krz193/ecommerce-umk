import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/utils/date_formatter.dart';
import 'package:mobile/features/notification/models/notification_model.dart';
import 'package:mobile/features/notification/providers/notification_provider.dart';
import 'package:mobile/features/notification/widgets/notification_bell_button.dart';

class NotificationListPage extends ConsumerStatefulWidget {
  const NotificationListPage({super.key});

  @override
  ConsumerState<NotificationListPage> createState() =>
      _NotificationListPageState();
}

class _NotificationListPageState extends ConsumerState<NotificationListPage> {
  String _selectedCategory = 'all';
  bool _isMarkingAll = false;

  static const _categories = [
    ('all', 'Semua'),
    ('transaction', 'Transaksi'),
    ('promo', 'Promo'),
    ('system', 'Sistem'),
  ];

  Future<void> _markAllRead() async {
    setState(() => _isMarkingAll = true);
    try {
      await ref.read(notificationServiceProvider).markAllAsRead();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua notifikasi ditandai sudah dibaca')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menandai notifikasi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isMarkingAll = false);
      }
    }
  }

  Future<void> _handleTapNotification(AppNotificationModel item) async {
    if (!item.isRead) {
      try {
        await ref.read(notificationServiceProvider).markAsRead(item.id);
      } catch (_) {
        // Keep navigation responsive even if markAsRead fails transiently
      }
    }
    if (!mounted) return;
    if (item.targetRoute != null && item.targetRoute!.trim().isNotEmpty) {
      navigateToNotificationTarget(context, item);
    }
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'transaction' => Icons.receipt_long_rounded,
      'promo' => Icons.bolt_rounded,
      _ => Icons.notifications_active_outlined,
    };
  }

  Color _categoryColor(String category) {
    return switch (category) {
      'transaction' => AppColors.info,
      'promo' => AppColors.primary,
      _ => AppColors.primaryHover,
    };
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _isMarkingAll ? null : _markAllRead,
              icon: _isMarkingAll
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all, size: 18),
              label: const Text('Tandai Dibaca'),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (key, label) = _categories[index];
                final isSelected = _selectedCategory == key;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  selectedColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primaryHover
                        : AppColors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedCategory = key);
                  },
                );
              },
            ),
          ),
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Gagal memuat notifikasi: $err'),
                ),
              ),
              data: (notifications) {
                final filtered = _selectedCategory == 'all'
                    ? notifications
                    : notifications
                        .where((n) => n.category == _selectedCategory)
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada notifikasi pada kategori ini',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final accent = _categoryColor(item.category);

                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        ref
                            .read(notificationServiceProvider)
                            .deleteNotification(item.id)
                            .catchError((_) {});
                      },
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _handleTapNotification(item),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: item.isRead
                                ? Colors.white
                                : AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: item.isRead
                                  ? Colors.grey.shade200
                                  : AppColors.primary.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: accent.withAlpha(28),
                                child: Icon(
                                  _categoryIcon(item.category),
                                  color: accent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              fontWeight: item.isRead
                                                  ? FontWeight.w600
                                                  : FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (!item.isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.body,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormatter.format(item.createdAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        if (item.targetRoute != null &&
                                            item.targetRoute!.isNotEmpty)
                                          const Text(
                                            'Ketuk untuk buka →',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
