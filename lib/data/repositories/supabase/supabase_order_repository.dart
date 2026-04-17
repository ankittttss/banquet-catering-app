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

    final orderRow = await supabase
        .from('orders')
        .insert({
          'event_id': eventId,
          'user_id': userId,
          'food_cost': totals.foodCost,
          'banquet_charge': totals.banquetCharge,
          'delivery_charge': totals.deliveryCharge,
          'buffet_setup': totals.buffetSetup,
          'service_boy_cost': totals.serviceBoyCost,
          'water_bottle_cost': totals.waterBottleCost,
          'platform_fee': totals.platformFee,
          'subtotal': totals.subtotal,
          'gst': totals.gst,
          'total': totals.total,
          'payment_status': PaymentStatus.pending.dbValue,
          'order_status': OrderStatus.placed.dbValue,
        })
        .select()
        .single();
    final orderId = orderRow['id'] as String;

    final items = cart
        .map((c) => {
              'order_id': orderId,
              'menu_item_id': c.item.id,
              'qty': c.qty,
              'price_at_order': c.item.price,
            })
        .toList();
    await supabase.from('order_items').insert(items);

    return orderId;
  }

  @override
  Stream<List<OrderSummary>> streamMyOrders(String userId) {
    // Realtime stream of the user's orders (without the events join — streams
    // don't support joins). We expose placed/confirmed/... timestamps and
    // driver metadata directly on orders, which is enough for the tracker.
    return supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map<OrderSummary>(OrderSummary.fromMap)
            .toList(growable: false));
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
