import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/notification/models/notification_model.dart';
import 'package:mobile/features/notification/services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationsStreamProvider =
    StreamProvider.autoDispose<List<AppNotificationModel>>((ref) {
      // Tie provider lifetime to auth state changes so account switching never leaks state
      ref.watch(authStateProvider);
      final user = supabase.auth.currentUser;
      if (user == null) {
        return Stream.value(const []);
      }

      final service = ref.read(notificationServiceProvider);
      return service.streamUserNotifications(user.id);
    });

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(notificationsStreamProvider).asData?.value;
  if (notifications == null) return 0;
  return notifications.where((n) => !n.isRead).length;
});
