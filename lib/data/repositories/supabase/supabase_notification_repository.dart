import '../../../core/supabase/supabase_client.dart';
import '../../models/app_notification.dart';
import '../notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  @override
  Stream<List<AppNotification>> streamMine(String userId) {
    return supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map<AppNotification>(AppNotification.fromMap)
            .toList(growable: false));
  }

  @override
  Future<List<AppNotification>> fetchMine(String userId) async {
    final rows = await supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return rows
        .map<AppNotification>(AppNotification.fromMap)
        .toList(growable: false);
  }

  @override
  Future<void> markRead(String notificationId) async {
    await supabase.rpc<void>(
      'mark_notification_read',
      params: {'p_id': notificationId},
    );
  }

  @override
  Future<void> markAllRead() async {
    await supabase.rpc<void>('mark_all_notifications_read');
  }
}
