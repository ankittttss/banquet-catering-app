/// A notification for a user. Persisted in `public.notifications`.
/// Usually created by Postgres triggers on order-status changes.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.orderId,
    this.body,
    this.iconName,
    this.accentHex,
    this.bgHex,
    this.readAt,
  });

  final String id;
  final String userId;
  final String? orderId;
  final String kind;
  final String title;
  final String? body;
  final String? iconName;
  final String? accentHex;
  final String? bgHex;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        orderId: map['order_id'] as String?,
        kind: map['kind'] as String,
        title: map['title'] as String,
        body: map['body'] as String?,
        iconName: map['icon_name'] as String?,
        accentHex: map['accent_hex'] as String?,
        bgHex: map['bg_hex'] as String?,
        readAt: map['read_at'] == null
            ? null
            : DateTime.parse(map['read_at'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
