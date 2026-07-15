import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../models/cart_item.dart';
import '../../models/checkout_totals.dart';
import '../../models/event_draft.dart';
import '../../models/manager_event_detail.dart';
import '../../models/order.dart';
import '../order_repository.dart';

class SupabaseOrderRepository implements OrderRepository {
  @override
  Future<String> placeOrder({
    required String userId,
    required EventDraft event,
    required List<CartItem> cart,
    required CheckoutTotals totals,
  }) async {
    final eventPayload = event.toInsertMap(userId);
    Map<String, dynamic> eventRow;
    try {
      eventRow =
          await supabase.from('events').insert(eventPayload).select().single();
    } on PostgrestException catch (e) {
      // The optional `name` column may not be migrated yet on older schemas.
      // Drop it and retry so order placement never fails on that alone.
      final missingName = eventPayload.containsKey('name') &&
          e.message.toLowerCase().contains('name');
      if (!missingName) rethrow;
      eventPayload.remove('name');
      eventRow =
          await supabase.from('events').insert(eventPayload).select().single();
    }
    final eventId = eventRow['id'] as String;

    // Group cart lines by restaurant — becomes one vendor lot per kitchen.
    final byRestaurant = <String, List<CartItem>>{};
    final orderedRestaurants = <String>[];
    for (final line in cart) {
      final rid = line.item.restaurantId;
      if (!byRestaurant.containsKey(rid)) {
        orderedRestaurants.add(rid);
        byRestaurant[rid] = <CartItem>[];
      }
      byRestaurant[rid]!.add(line);
    }

    // orders.restaurant_id is kept as a "primary kitchen" hint for legacy
    // review lookups. For multi-vendor orders we just take the first.
    final primaryRestaurantId =
        orderedRestaurants.isNotEmpty ? orderedRestaurants.first : null;

    final orderRow = await supabase
        .from('orders')
        .insert({
          'event_id': eventId,
          'user_id': userId,
          if (primaryRestaurantId != null) 'restaurant_id': primaryRestaurantId,
          'food_cost': totals.foodCost,
          'banquet_charge': totals.banquetCharge,
          'delivery_charge': totals.deliveryCharge,
          'buffet_setup': totals.buffetSetup,
          'service_boy_cost': totals.serviceBoyCost,
          'service_boy_count': totals.serviceBoyCount,
          'water_bottle_cost': totals.waterBottleCost,
          'platform_fee': totals.platformFee,
          'subtotal': totals.subtotal,
          // Persist GST + service tax in the single gst column so
          // total = subtotal + gst stays internally consistent without
          // requiring a service_tax column migration.
          'gst': totals.gst + totals.serviceTax,
          'total': totals.total,
          'payment_status': PaymentStatus.pending.dbValue,
          'order_status': OrderStatus.placed.dbValue,
        })
        .select()
        .single();
    final orderId = orderRow['id'] as String;

    // Create one vendor lot per restaurant, compute its subtotal from the
    // group's billed (per-guest × guest count) line totals.
    final guestCount = event.guestCount;
    final lotIdByRestaurant = <String, String>{};
    for (final rid in orderedRestaurants) {
      final lines = byRestaurant[rid]!;
      final lotSubtotal =
          lines.fold<double>(0, (s, c) => s + c.billedLineTotal(guestCount));
      final lotRow = await supabase
          .from('order_vendor_lots')
          .insert({
            'order_id': orderId,
            'restaurant_id': rid,
            'subtotal': lotSubtotal,
            'status': 'pending',
          })
          .select()
          .single();
      lotIdByRestaurant[rid] = lotRow['id'] as String;
    }

    // Line items carry:
    //   qty            = portions per guest (legacy absolute for old carts)
    //   qty_per_guest  = explicit per-guest multiplier (always = qty in v1)
    //   vendor_lot_id  = kitchen slice this line belongs to
    final items = cart.map((c) {
      final rid = c.item.restaurantId;
      return {
        'order_id': orderId,
        'menu_item_id': c.item.id,
        'qty': c.qty,
        'qty_per_guest': c.qty,
        'price_at_order': c.unitPrice,
        if (lotIdByRestaurant.containsKey(rid))
          'vendor_lot_id': lotIdByRestaurant[rid],
      };
    }).toList();
    await supabase.from('order_items').insert(items);

    return orderId;
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
