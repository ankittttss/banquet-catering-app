import 'dart:async';

import '../../models/app_notification.dart';
import '../notification_repository.dart';

/// In-memory notifications for UI dev. Populated with a few sample items so
/// the Notifications screen isn't empty.
class StubNotificationRepository implements NotificationRepository {
  final _controller = StreamController<List<AppNotification>>.broadcast();
  final List<AppNotification> _items = [
    AppNotification(
      id: 'n1',
      userId: 'local',
      kind: 'order_delivered',
      title: 'Order delivered!',
      body:
          'Your order from Spice Route Catering has been delivered. Rate it.',
      iconName: 'celebration',
      accentHex: '#1BA672',
      bgHex: '#EAFAF1',
      readAt: DateTime.now().subtract(const Duration(hours: 2)),
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'n2',
      userId: 'local',
      kind: 'promo',
      title: 'Flash sale! 60% OFF',
      body: 'Use code FEAST60 on your next event order. Valid till midnight.',
      iconName: 'local_offer',
      accentHex: '#E23744',
      bgHex: '#FFF1F2',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    AppNotification(
      id: 'n3',
      userId: 'local',
      kind: 'driver_assigned',
      title: 'Driver assigned',
      body: 'Ravi Kumar is on the way to pick up your order.',
      iconName: 'delivery_dining',
      accentHex: '#2B6CB0',
      bgHex: '#EBF4FF',
      readAt: DateTime.now().subtract(const Duration(days: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: 'n4',
      userId: 'local',
      kind: 'system',
      title: 'New: Wedding packages',
      body:
          'Explore curated wedding menus starting at ₹250 per plate for 100+ guests.',
      iconName: 'celebration',
      accentHex: '#9B59B6',
      bgHex: '#F3E8FF',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Stream<List<AppNotification>> streamMine(String userId) async* {
    yield List.unmodifiable(_items);
    yield* _controller.stream;
  }

  @override
  Future<List<AppNotification>> fetchMine(String userId) async =>
      List.unmodifiable(_items);

  @override
  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i == -1) return;
    final n = _items[i];
    _items[i] = AppNotification(
      id: n.id,
      userId: n.userId,
      orderId: n.orderId,
      kind: n.kind,
      title: n.title,
      body: n.body,
      iconName: n.iconName,
      accentHex: n.accentHex,
      bgHex: n.bgHex,
      readAt: n.readAt ?? DateTime.now(),
      createdAt: n.createdAt,
    );
    _controller.add(List.unmodifiable(_items));
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].readAt != null) continue;
      final n = _items[i];
      _items[i] = AppNotification(
        id: n.id,
        userId: n.userId,
        orderId: n.orderId,
        kind: n.kind,
        title: n.title,
        body: n.body,
        iconName: n.iconName,
        accentHex: n.accentHex,
        bgHex: n.bgHex,
        readAt: DateTime.now(),
        createdAt: n.createdAt,
      );
    }
    _controller.add(List.unmodifiable(_items));
  }
}
