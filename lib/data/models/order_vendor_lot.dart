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
    this.items = const [],
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

  /// Per-menu-item lines that make up this lot. Populated when the
  /// caller pulls `order_vendor_lots → order_items(menu_items(name,...))`
  /// — empty otherwise.
  final List<VendorLotItem> items;

  factory OrderVendorLot.fromMap(Map<String, dynamic> map) {
    final rawItems = map['order_items'];
    final items = <VendorLotItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          items.add(
            VendorLotItem.fromMap(raw.cast<String, dynamic>()),
          );
        }
      }
    }
    return OrderVendorLot(
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
      items: items,
    );
  }

  static DateTime? _parse(Object? raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }
}

/// One line on a vendor lot — a specific menu item ordered with its
/// per-guest quantity and the price snapshot taken when the order was
/// placed. Built from the joined PostgREST shape
/// `order_items(qty, qty_per_guest, price_at_order, menu_items(name, is_veg))`.
class VendorLotItem {
  const VendorLotItem({
    required this.qty,
    required this.priceAtOrder,
    this.qtyPerGuest,
    this.name,
    this.isVeg,
  });

  /// Legacy absolute quantity (in older carts this was the per-order
  /// total). New rows mirror [qtyPerGuest] here so we keep a single
  /// "how many?" handle for the UI.
  final int qty;

  /// Snapshot of the menu item's unit price at the moment of ordering
  /// — what the customer was actually billed for.
  final double priceAtOrder;

  /// Per-guest multiplier (current cart semantic).
  final double? qtyPerGuest;

  final String? name;
  final bool? isVeg;

  /// Line total used in the UI. We prefer `qtyPerGuest * price`
  /// because that's what the bill summed; falls back to `qty * price`
  /// for legacy rows.
  double lineTotal(int guestCount) {
    final per = qtyPerGuest;
    if (per != null && guestCount > 0) {
      return per * priceAtOrder * guestCount;
    }
    return qty * priceAtOrder;
  }

  factory VendorLotItem.fromMap(Map<String, dynamic> map) {
    final menu = map['menu_items'];
    return VendorLotItem(
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      priceAtOrder: (map['price_at_order'] as num?)?.toDouble() ?? 0,
      qtyPerGuest: (map['qty_per_guest'] as num?)?.toDouble(),
      name: menu is Map ? menu['name'] as String? : null,
      isVeg: menu is Map ? menu['is_veg'] as bool? : null,
    );
  }
}
