import '../models/app_notification.dart';

abstract interface class NotificationRepository {
  /// Realtime stream of the user's notifications, newest first.
  Stream<List<AppNotification>> streamMine(String userId);
  Future<List<AppNotification>> fetchMine(String userId);
  Future<void> markRead(String notificationId);
  Future<void> markAllRead();
}
