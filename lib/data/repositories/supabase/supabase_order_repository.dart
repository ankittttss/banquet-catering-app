import '../../../core/supabase/supabase_client.dart';
import '../../models/cart_item.dart';
import '../../models/checkout_totals.dart';
import '../../models/event_draft.dart';
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
    final eventRow = await supabase
        .from('events')
        .insert(event.toInsertMap(userId))
        .select()
        .single();
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
          if (primaryRestaurantId != null)
            'restaurant_id': primaryRestaurantId,
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
    // 1. Always yield an initial REST fetch so the UI has data even if
    //    Realtime subscription fails / times out.
    try {
      final rows = await supabase
          .from('orders')
          .select('*, events(event_date, location, guest_count)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      yield rows
          .map<OrderSummary>(OrderSummary.fromMap)
          .toList(growable: false);
    } catch (_) {
      yield const <OrderSummary>[];
    }

    // 2. Try to overlay a realtime stream. If it errors out (publication,
    //    replica identity, or subscribe timeout), swallow — the UI keeps
    //    showing the initial fetch above. Pull-to-refresh still works.
    try {
      final stream = supabase
          .from('orders')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false);
      await for (final rows in stream) {
        yield rows
            .where((r) => r['user_id'] == userId)
            .map<OrderSummary>(OrderSummary.fromMap)
            .toList(growable: false);
      }
    } catch (_) {
      // Realtime unavailable — initial data already surfaced. No-op.
    }
  }

  @override
  Future<List<OrderSummary>> fetchAll() async {
    final rows = await supabase
        .from('orders')
        .select('*, events(event_date, location, guest_count)')
        .order('created_at', ascending: false);
    return rows
        .map<OrderSummary>(OrderSummary.fromMap)
        .toList(growable: false);
  }

  @override
  Future<void> updateStatus(String orderId, OrderStatus status) async {
    await supabase
        .from('orders')
        .update({'order_status': status.dbValue}).eq('id', orderId);
  }
}
