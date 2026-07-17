import '../../../core/supabase/supabase_client.dart';
import '../../models/cart_item.dart';
import '../../models/checkout_totals.dart';
import '../../models/event_draft.dart';
import '../../models/manager_event_detail.dart';
import '../../models/menu_item.dart';
import '../../models/order.dart';
import '../order_payloads.dart';
import '../order_repository.dart';

class SupabaseOrderRepository implements OrderRepository {
  @override
  Future<String> placeOrder({
    required String userId,
    required EventDraft event,
    required List<CartItem> cart,
    required CheckoutTotals totals,
  }) async {
    // ONE transactional RPC (phase38) replaces the old 4-step client-side
    // insert sequence that could strand a partial booking. The server
    // re-validates availability / publish state / min-guests / venue
    // capacity / date-time ordering and computes pricing authoritatively
    // from DB prices + charges_config; `totals` only supplies the inputs
    // the server can't derive (service boys, tax opt-in, add-on total).
    // The signed-in user is taken from auth.uid() server-side — `userId`
    // is intentionally not sent.
    final res = await supabase.rpc<dynamic>(
      'place_order',
      params: {
        'p_event': orderEventPayload(event),
        'p_items': orderItemsPayload(cart),
        'p_service_boy_count': totals.serviceBoyCount,
        'p_include_service_tax': totals.serviceTax > 0,
        'p_addons_total': totals.setupEquipment,
      },
    );
    return (res as Map)['order_id'] as String;
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    // Server-enforced: only the owner, only placed/confirmed, and the
    // cancellation cascades to pending vendor lots (phase38 trigger).
    await supabase.rpc<dynamic>(
      'cancel_my_order',
      params: {'p_order_id': orderId},
    );
  }

  @override
  Future<List<CartItem>> fetchReorderLines(String orderId) async {
    final rows = await supabase
        .from('order_items')
        .select('qty_per_guest, qty, portion, spice, notes, menu_items(*)')
        .eq('order_id', orderId);
    final lines = <CartItem>[];
    for (final r in rows) {
      final mi = r['menu_items'];
      if (mi is! Map<String, dynamic>) continue;
      // Skip dishes that are no longer orderable — the cart re-checks too,
      // but there's no point resurrecting a dead line.
      if (mi['deleted_at'] != null) continue;
      final MenuItem item;
      try {
        item = MenuItem.fromMap(mi);
      } catch (_) {
        continue; // malformed/partial row — skip rather than crash reorder
      }
      if (!item.isAvailable) continue;
      final qtyPerGuest =
          (r['qty_per_guest'] as num?) ?? (r['qty'] as num?) ?? 1;
      lines.add(
        CartItem(
          item: item,
          qty: qtyPerGuest.round().clamp(1, 99),
          portion: Portion.values.firstWhere(
            (p) => p.name == r['portion'],
            orElse: () => Portion.regular,
          ),
          spice: SpiceLevel.values.firstWhere(
            (s) => s.name == r['spice'],
            orElse: () => SpiceLevel.medium,
          ),
          notes: (r['notes'] ?? '') as String,
        ),
      );
    }
    return lines;
  }

  @override
  Stream<List<OrderSummary>> streamMyOrders(String userId) async* {
    // The joined query lets PostgREST embed the parent event (name, date,
    // location, guest count) onto each order. Realtime row streams CANNOT
    // embed related tables, so we run this authoritative fetch both for the
    // initial paint and on every realtime signal — otherwise the live
    // overlay would clobber those event fields back to null (cards would
    // show a generic "Event" with no guests/venue).
    Future<List<OrderSummary>> fetchJoined() async {
      final rows = await supabase
          .from('orders')
          .select('*, events(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return rows
          .map<OrderSummary>(OrderSummary.fromMap)
          .toList(growable: false);
    }

    // 1. Initial fetch so the UI has fully-hydrated data immediately.
    try {
      yield await fetchJoined();
    } catch (_) {
      yield const <OrderSummary>[];
    }

    // 2. Use realtime purely as a "something changed" trigger, then re-run
    //    the joined fetch so event name/date/location/guests stay attached.
    //    If realtime is unavailable (publication, replica identity, or
    //    subscribe timeout), the initial data above still stands and
    //    pull-to-refresh keeps working.
    try {
      final stream = supabase
          .from('orders')
          .stream(primaryKey: ['id']).eq('user_id', userId);
      await for (final _ in stream) {
        try {
          yield await fetchJoined();
        } catch (_) {
          // Transient fetch error — keep the last good list on screen.
        }
      }
    } catch (_) {
      // Realtime unavailable — initial data already surfaced. No-op.
    }
  }

  @override
  Future<List<OrderSummary>> fetchAll() async {
    final rows = await supabase
        .from('orders')
        .select('*, events(*)')
        .order('created_at', ascending: false);
    return rows.map<OrderSummary>(OrderSummary.fromMap).toList(growable: false);
  }

  @override
  Future<void> updateStatus(String orderId, OrderStatus status) async {
    await supabase
        .from('orders')
        .update({'order_status': status.dbValue}).eq('id', orderId);
  }

  @override
  Future<ManagerEventDetail?> fetchEventDetail(String eventId) async {
    // One round-trip: event row + venue + tier + the booking order +
    // each restaurant's vendor lot with the restaurant's display name.
    // PostgREST returns `orders` and `order_vendor_lots` as nested
    // arrays — the model handles the unwrap.
    final row = await supabase
        .from('events')
        .select(
          '*, '
          'banquet_venues(name), '
          'event_tiers(label, code), '
          'orders('
          'id, order_status, payment_status, total, subtotal, food_cost, '
          'banquet_charge, delivery_charge, buffet_setup, service_boy_cost, '
          'service_boy_count, water_bottle_cost, platform_fee, gst, '
          'created_at, '
          'order_vendor_lots('
          '*, '
          'restaurants(name), '
          'order_items(qty, qty_per_guest, price_at_order, '
          '  menu_items(name, is_veg)'
          ')'
          ')'
          ')',
        )
        .eq('id', eventId)
        .maybeSingle();
    if (row == null) return null;
    final detail = ManagerEventDetail.fromMap(row);
    return _attachCustomer(detail);
  }

  /// Hydrates the customer name/phone/email on the detail snapshot via
  /// a single profile lookup. RLS (phase 28) lets the operator and any
  /// assigned staff read the customer row.
  Future<ManagerEventDetail> _attachCustomer(ManagerEventDetail d) async {
    final uid = d.userId;
    if (uid == null || uid.isEmpty) return d;
    try {
      final p = await supabase
          .from('profiles')
          .select('name, phone, email')
          .eq('id', uid)
          .maybeSingle();
      if (p == null) return d;
      return d.withCustomer(
        name: p['name'] as String?,
        phone: p['phone'] as String?,
        email: p['email'] as String?,
      );
    } catch (_) {
      return d;
    }
  }
}
