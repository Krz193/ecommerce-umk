import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/notification/models/notification_model.dart';
import 'package:mobile/features/notification/providers/notification_provider.dart';

const _shellRoutes = {'/home', '/explore', '/orders', '/account', '/feedback'};

void navigateToNotificationTarget(
  BuildContext context,
  AppNotificationModel notification,
) {
  final route = notification.targetRoute?.trim();
  if (route == null || route.isEmpty) {
    context.push('/notifications');
    return;
  }

  if (_shellRoutes.contains(route)) {
    context.go(route);
    return;
  }

  context.push(route);
}

class NotificationBellButton extends ConsumerStatefulWidget {
  const NotificationBellButton({super.key});

  @override
  ConsumerState<NotificationBellButton> createState() =>
      _NotificationBellButtonState();
}

class _NotificationBellButtonState
    extends ConsumerState<NotificationBellButton> {
  static String? _lastBannerNotificationId;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    ref.listen<AsyncValue<List<AppNotificationModel>>>(
      notificationsStreamProvider,
      (previous, next) {
        final items = next.asData?.value;
        if (items == null) return;

        final latestUnread = items.where((n) => !n.isRead).firstOrNull;
        if (!_initialized) {
          _initialized = true;
          if (latestUnread != null && _lastBannerNotificationId == null) {
            _lastBannerNotificationId = latestUnread.id;
          }
          return;
        }

        if (latestUnread == null ||
            latestUnread.id == _lastBannerNotificationId) {
          return;
        }

        _lastBannerNotificationId = latestUnread.id;
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
          return;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.textPrimary,
              duration: const Duration(seconds: 4),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latestUnread.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    latestUnread.body,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'Lihat',
                textColor: AppColors.accent,
                onPressed: () {
                  ref
                      .read(notificationServiceProvider)
                      .markAsRead(latestUnread.id)
                      .catchError((_) {});
                  if (context.mounted) {
                    navigateToNotificationTarget(context, latestUnread);
                  }
                },
              ),
            ),
          );
      },
    );

    return IconButton(
      tooltip: 'Notifikasi',
      onPressed: () => context.push('/notifications'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (unreadCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
