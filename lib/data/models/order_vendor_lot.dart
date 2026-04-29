/// One vendor lot on a multi-restaurant order. Status machine lives here —
/// each kitchen moves its own slice independently while customers see a
/// single unified booking.
enum VendorLotStatus {
  pending('pending', 'Pending'),
  accepted('accepted', 'Accepted'),
  preparing('preparing', 'Preparing'),
  readyForPickup('ready_for_pickup', 'Ready for pickup'),
  pickedUp('picked_up', 'Picked up'),
  delivered('delivered', 'Delivered'),
  cancelled('cancelled', 'Cancelled');

  const VendorLotStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static VendorLotStatus fromString(String? value) {
    for (final s in values) {
      if (s.dbValue == value) return s;
    }
    return VendorLotStatus.pending;
  }
}

class OrderVendorLot {
  const OrderVendorLot({
    required this.id,
    required this.orderId,
    required this.restaurantId,
    required this.subtotal,
    required this.status,
    this.restaurantName,
    this.acceptedAt,
    this.readyAt,
    this.pickedUpAt,
    this.deliveredAt,
  });

  final String id;
  final String orderId;
  final String restaurantId;
  final double subtotal;
  final VendorLotStatus status;
  final String? restaurantName;
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  factory OrderVendorLot.fromMap(Map<String, dynamic> map) => OrderVendorLot(
        id: map['id'] as String,
        orderId: map['order_id'] as String,
        restaurantId: map['restaurant_id'] as String,
        subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
        status: VendorLotStatus.fromString(map['status'] as String?),
        restaurantName: map['restaurant_name'] as String?,
        acceptedAt: _parse(map['accepted_at']),
        readyAt: _parse(map['ready_at']),
        pickedUpAt: _parse(map['picked_up_at']),
        deliveredAt: _parse(map['delivered_at']),
      );

  static DateTime? _parse(Object? raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }
}
