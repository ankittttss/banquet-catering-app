import '../../../core/supabase/supabase_client.dart';
import '../../models/app_notification.dart';
import '../notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  @override
  Stream<List<AppNotification>> streamMine(String userId) async* {
    try {
      final rows = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      yield rows
          .map<AppNotification>(AppNotification.fromMap)
          .toList(growable: false);
    } catch (_) {
      yield const <AppNotification>[];
    }
    try {
      final stream = supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false);
      await for (final rows in stream) {
        yield rows
            .where((r) => r['user_id'] == userId)
            .map<AppNotification>(AppNotification.fromMap)
            .toList(growable: false);
      }
    } catch (_) {
      // Realtime unavailable — initial fetch already surfaced.
    }
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
