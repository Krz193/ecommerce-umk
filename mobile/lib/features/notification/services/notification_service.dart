import 'package:mobile/core/config/supabase_provider.dart';
import 'package:mobile/features/notification/models/notification_model.dart';

class NotificationService {
  Stream<List<AppNotificationModel>> streamUserNotifications(String userId) {
    return supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100)
        .map(
          (rows) => rows
              .map<AppNotificationModel>(AppNotificationModel.fromJson)
              .toList(),
        );
  }

  Future<void> markAsRead(String notificationId) async {
    await supabase
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    await supabase.rpc('mark_all_notifications_read');
  }

  Future<void> deleteNotification(String notificationId) async {
    await supabase.from('notifications').delete().eq('id', notificationId);
  }
}
