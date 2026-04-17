import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_notification.dart';
import 'auth_providers.dart';
import 'repositories_providers.dart';

final notificationsStreamProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUserIdProvider) ?? 'local';
  return ref.read(notificationRepositoryProvider).streamMine(uid);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final list =
      ref.watch(notificationsStreamProvider).valueOrNull ?? const [];
  return list.where((n) => n.isUnread).length;
});
