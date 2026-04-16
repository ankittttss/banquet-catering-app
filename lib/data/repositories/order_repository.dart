import '../../core/config/app_config.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/cart_item.dart';
import '../models/charges_config.dart';
import '../models/event_draft.dart';
import '../models/order.dart';

/// Aggregated totals computed at checkout time.
class CheckoutTotals {
  const CheckoutTotals({
    required this.foodCost,
    required this.banquetCharge,
    required this.deliveryCharge,
    required this.buffetSetup,
    required this.serviceBoyCost,
    required this.waterBottleCost,
    required this.platformFee,
    required this.subtotal,
    required this.gst,
    required this.total,
  });

  final double foodCost;
  final double banquetCharge;
  final double deliveryCharge;
  final double buffetSetup;
  final double serviceBoyCost;
  final double waterBottleCost;
  final double platformFee;
  final double subtotal;
  final double gst;
  final double total;

  static CheckoutTotals compute({
    required List<CartItem> cart,
    required ChargesConfig charges,
    required Map<String, double> deliveryByRestaurant,
  }) {
    final food = cart.fold<double>(0, (s, i) => s + i.lineTotal);
    final delivery =
        deliveryByRestaurant.values.fold<double>(0, (s, d) => s + d);
    final subtotal = food +
        charges.banquetCharge +
        delivery +
        charges.buffetSetup +
        charges.serviceBoyCost +
        charges.waterBottleCost +
        charges.platformFee;
    final gst = subtotal * (charges.gstPercent / 100);
    final total = subtotal + gst;
    return CheckoutTotals(
      foodCost: food,
      banquetCharge: charges.banquetCharge,
      deliveryCharge: delivery,
      buffetSetup: charges.buffetSetup,
      serviceBoyCost: charges.serviceBoyCost,
      waterBottleCost: charges.waterBottleCost,
      platformFee: charges.platformFee,
      subtotal: subtotal,
      gst: gst,
      total: total,
    );
  }
}

class OrderRepository {
  OrderRepository();

  Future<String> placeOrder({
    required String userId,
    required EventDraft event,
    required List<CartItem> cart,
    required CheckoutTotals totals,
  }) async {
    if (!AppConfig.hasSupabase) {
      // Offline / unconfigured — return a fake id so UI can proceed.
      return 'local-${DateTime.now().millisecondsSinceEpoch}';
    }

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

  /// Realtime-friendly stream of the current user's orders.
  Stream<List<OrderSummary>> streamMyOrders(String userId) {
    if (!AppConfig.hasSupabase) return const Stream.empty();
    return supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        .map((rows) => rows
            .map<OrderSummary>((r) => OrderSummary.fromMap(r))
            .toList(growable: false));
  }

  Future<List<OrderSummary>> fetchAll() async {
    if (!AppConfig.hasSupabase) return const [];
    final rows = await supabase
        .from('orders')
        .select('*, events(event_date, location, guest_count)')
        .order('created_at', ascending: false);
    return rows
        .map<OrderSummary>((r) => OrderSummary.fromMap(r))
        .toList(growable: false);
  }

  Future<void> updateStatus(String orderId, OrderStatus status) async {
    if (!AppConfig.hasSupabase) return;
    await supabase
        .from('orders')
        .update({'order_status': status.dbValue}).eq('id', orderId);
  }
}
