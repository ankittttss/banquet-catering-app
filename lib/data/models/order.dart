enum OrderStatus {
  placed,
  confirmed,
  preparing,
  dispatched,
  delivered,
  cancelled;

  static OrderStatus fromString(String? v) {
    return switch (v) {
      'confirmed' => OrderStatus.confirmed,
      'preparing' => OrderStatus.preparing,
      'dispatched' => OrderStatus.dispatched,
      'delivered' => OrderStatus.delivered,
      'cancelled' => OrderStatus.cancelled,
      _ => OrderStatus.placed,
    };
  }

  String get label => switch (this) {
        OrderStatus.placed => 'Placed',
        OrderStatus.confirmed => 'Confirmed',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.dispatched => 'Out for delivery',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  String get dbValue => name;

  /// 0-based position in the tracker pipeline. Cancelled returns -1.
  int get stepIndex => switch (this) {
        OrderStatus.placed => 0,
        OrderStatus.confirmed => 1,
        OrderStatus.preparing => 2,
        OrderStatus.dispatched => 3,
        OrderStatus.delivered => 4,
        OrderStatus.cancelled => -1,
      };
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded;

  static PaymentStatus fromString(String? v) => switch (v) {
        'paid' => PaymentStatus.paid,
        'failed' => PaymentStatus.failed,
        'refunded' => PaymentStatus.refunded,
        _ => PaymentStatus.pending,
      };

  String get dbValue => name;
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.eventId,
    required this.total,
    required this.orderStatus,
    required this.paymentStatus,
    required this.createdAt,
    this.eventDate,
    this.location,
    this.guestCount,
    this.driverName,
    this.driverPhone,
    this.driverRating,
    this.driverAvatarHex,
    this.etaMinutesMin,
    this.etaMinutesMax,
    this.placedAt,
    this.confirmedAt,
    this.preparingAt,
    this.dispatchedAt,
    this.deliveredAt,
    this.cancelledAt,
  });

  final String id;
  final String eventId;
  final double total;
  final OrderStatus orderStatus;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;

  // Joined from events table.
  final DateTime? eventDate;
  final String? location;
  final int? guestCount;

  // Driver metadata (from Phase 3 migration).
  final String? driverName;
  final String? driverPhone;
  final double? driverRating;
  final String? driverAvatarHex;

  // ETA window.
  final int? etaMinutesMin;
  final int? etaMinutesMax;

  // Status transition timestamps.
  final DateTime? placedAt;
  final DateTime? confirmedAt;
  final DateTime? preparingAt;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;

  factory OrderSummary.fromMap(Map<String, dynamic> map) {
    final event = map['events'] as Map<String, dynamic>?;
    DateTime? _ts(String key) {
      final v = map[key];
      if (v == null) return null;
      return DateTime.tryParse(v as String);
    }

    return OrderSummary(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      total: (map['total'] as num).toDouble(),
      orderStatus: OrderStatus.fromString(map['order_status'] as String?),
      paymentStatus:
          PaymentStatus.fromString(map['payment_status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      eventDate: event?['event_date'] != null
          ? DateTime.parse(event!['event_date'] as String)
          : null,
      location: event?['location'] as String?,
      guestCount: (event?['guest_count'] as num?)?.toInt(),
      driverName: map['driver_name'] as String?,
      driverPhone: map['driver_phone'] as String?,
      driverRating: (map['driver_rating'] as num?)?.toDouble(),
      driverAvatarHex: map['driver_avatar_hex'] as String?,
      etaMinutesMin: (map['eta_minutes_min'] as num?)?.toInt(),
      etaMinutesMax: (map['eta_minutes_max'] as num?)?.toInt(),
      placedAt: _ts('placed_at') ?? DateTime.parse(map['created_at'] as String),
      confirmedAt: _ts('confirmed_at'),
      preparingAt: _ts('preparing_at'),
      dispatchedAt: _ts('dispatched_at'),
      deliveredAt: _ts('delivered_at'),
      cancelledAt: _ts('cancelled_at'),
    );
  }
}
