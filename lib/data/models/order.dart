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
        OrderStatus.dispatched => 'Dispatched',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  String get dbValue => name;
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
  });

  final String id;
  final String eventId;
  final double total;
  final OrderStatus orderStatus;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime? eventDate;
  final String? location;
  final int? guestCount;

  factory OrderSummary.fromMap(Map<String, dynamic> map) {
    final event = map['events'] as Map<String, dynamic>?;
    return OrderSummary(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      total: (map['total'] as num).toDouble(),
      orderStatus:
          OrderStatus.fromString(map['order_status'] as String?),
      paymentStatus:
          PaymentStatus.fromString(map['payment_status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      eventDate: event?['event_date'] != null
          ? DateTime.parse(event!['event_date'] as String)
          : null,
      location: event?['location'] as String?,
      guestCount: (event?['guest_count'] as num?)?.toInt(),
    );
  }
}
