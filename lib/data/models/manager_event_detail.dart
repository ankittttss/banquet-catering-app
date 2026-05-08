import 'banquet_venue.dart';
import 'order.dart';
import 'order_vendor_lot.dart';

/// Aggregated, manager-facing snapshot of one event.
///
/// Bundles the event row, the booking order (if placed), and the per-
/// restaurant vendor lots so the manager event-detail screen can render
/// the full operational picture in one place. Roster (manager + service
/// boys) is fetched separately via `eventStaffProvider` so this stays
/// focused on the booking facts.
class ManagerEventDetail {
  const ManagerEventDetail({
    required this.eventId,
    this.eventDate,
    this.location,
    this.session,
    this.startTime,
    this.endTime,
    this.guestCount,
    this.banquetVenueName,
    this.banquetStatus,
    this.banquetNotes,
    this.tierLabel,
    this.tierCode,
    this.orderId,
    this.orderStatus,
    this.paymentStatus,
    this.total,
    this.subtotal,
    this.foodCost,
    this.banquetCharge,
    this.deliveryCharge,
    this.buffetSetup,
    this.serviceBoyCost,
    this.serviceBoyCount,
    this.waterBottleCost,
    this.platformFee,
    this.gst,
    this.orderCreatedAt,
    this.vendorLots = const [],
  });

  // ── Event facts ──────────────────────────────────────────────
  final String eventId;
  final DateTime? eventDate;
  final String? location;
  final String? session;

  /// `HH:MM` strings as stored in Postgres `time` columns.
  final String? startTime;
  final String? endTime;

  final int? guestCount;
  final String? banquetVenueName;

  /// Where the booking sits in the operator's pipeline
  /// (pending / accepted / declined / cancelled / completed). Drives
  /// which action bar the operator sees in the booking-detail screen.
  final BanquetEventStatus? banquetStatus;

  /// Free-text note written by the operator on this booking row.
  final String? banquetNotes;

  final String? tierLabel;
  final String? tierCode;

  // ── Booking / order ─────────────────────────────────────────
  final String? orderId;
  final OrderStatus? orderStatus;
  final PaymentStatus? paymentStatus;
  final double? total;
  final double? subtotal;
  final double? foodCost;
  final double? banquetCharge;
  final double? deliveryCharge;
  final double? buffetSetup;
  final double? serviceBoyCost;
  final int? serviceBoyCount;
  final double? waterBottleCost;
  final double? platformFee;
  final double? gst;
  final DateTime? orderCreatedAt;

  // ── Per-restaurant lots ─────────────────────────────────────
  final List<OrderVendorLot> vendorLots;

  bool get hasOrder => orderId != null;

  /// Tolerant parser for the joined PostgREST payload returned by
  /// `events?id=eq.{id}&select=*,banquet_venues(name),event_tiers(label,code),
  ///  orders(*, order_vendor_lots(*, restaurants(name)))`.
  factory ManagerEventDetail.fromMap(Map<String, dynamic> map) {
    final venue = map['banquet_venues'];
    final tier = map['event_tiers'];
    // `orders` is an array via PostgREST — pick the most recent if many.
    final ordersRaw = map['orders'];
    Map<String, dynamic>? order;
    if (ordersRaw is List && ordersRaw.isNotEmpty) {
      order = (ordersRaw.first as Map).cast<String, dynamic>();
    } else if (ordersRaw is Map) {
      order = ordersRaw.cast<String, dynamic>();
    }

    final lotRows = (order?['order_vendor_lots'] as List?) ?? const [];
    final lots = <OrderVendorLot>[];
    for (final raw in lotRows) {
      if (raw is! Map) continue;
      final mp = raw.cast<String, dynamic>();
      // Hoist the joined restaurant name into the flat key so the
      // existing OrderVendorLot.fromMap can read it transparently.
      final r = mp['restaurants'];
      if (r is Map && r['name'] is String) {
        mp['restaurant_name'] = r['name'] as String;
      }
      lots.add(OrderVendorLot.fromMap(mp));
    }

    return ManagerEventDetail(
      eventId: map['id'] as String,
      eventDate: _date(map['event_date']),
      location: map['location'] as String?,
      session: map['session'] as String?,
      startTime: map['start_time'] as String?,
      endTime: map['end_time'] as String?,
      guestCount: (map['guest_count'] as num?)?.toInt(),
      banquetVenueName:
          venue is Map ? venue['name'] as String? : null,
      banquetStatus: map['banquet_status'] is String
          ? BanquetEventStatus.fromString(map['banquet_status'] as String?)
          : null,
      banquetNotes: map['banquet_notes'] as String?,
      tierLabel: tier is Map ? tier['label'] as String? : null,
      tierCode: tier is Map ? tier['code'] as String? : null,
      orderId: order?['id'] as String?,
      orderStatus: order != null
          ? OrderStatus.fromString(order['order_status'] as String?)
          : null,
      paymentStatus: order != null
          ? PaymentStatus.fromString(order['payment_status'] as String?)
          : null,
      total: (order?['total'] as num?)?.toDouble(),
      subtotal: (order?['subtotal'] as num?)?.toDouble(),
      foodCost: (order?['food_cost'] as num?)?.toDouble(),
      banquetCharge: (order?['banquet_charge'] as num?)?.toDouble(),
      deliveryCharge: (order?['delivery_charge'] as num?)?.toDouble(),
      buffetSetup: (order?['buffet_setup'] as num?)?.toDouble(),
      serviceBoyCost: (order?['service_boy_cost'] as num?)?.toDouble(),
      serviceBoyCount: (order?['service_boy_count'] as num?)?.toInt(),
      waterBottleCost: (order?['water_bottle_cost'] as num?)?.toDouble(),
      platformFee: (order?['platform_fee'] as num?)?.toDouble(),
      gst: (order?['gst'] as num?)?.toDouble(),
      orderCreatedAt: order != null ? _date(order['created_at']) : null,
      vendorLots: lots,
    );
  }

  static DateTime? _date(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;
}
