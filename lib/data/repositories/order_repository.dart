import '../models/cart_item.dart';
import '../models/checkout_totals.dart';
import '../models/event_draft.dart';
import '../models/manager_event_detail.dart';
import '../models/order.dart';

abstract interface class OrderRepository {
  Future<String> placeOrder({
    required String userId,
    required EventDraft event,
    required List<CartItem> cart,
    required CheckoutTotals totals,
  });

  Stream<List<OrderSummary>> streamMyOrders(String userId);

  Future<List<OrderSummary>> fetchAll();

  Future<void> updateStatus(String orderId, OrderStatus status);

  /// Customer-initiated cancellation of their OWN order. Server-enforced:
  /// only placed/confirmed orders can be cancelled, and the cancellation
  /// cascades to the order's not-yet-picked-up vendor lots.
  Future<void> cancelOrder(String orderId);

  /// Rebuild cart lines from a past order — only items that are still
  /// orderable come back (deleted/unavailable dishes are skipped), priced at
  /// the CURRENT catalog price. Backs the "Reorder" action.
  Future<List<CartItem>> fetchReorderLines(String orderId);

  /// Aggregated event-level snapshot used by the manager event-detail
  /// screen: event row + venue/tier names + the booking order + per-
  /// restaurant vendor lots in a single query. Returns `null` when the
  /// event id doesn't exist.
  Future<ManagerEventDetail?> fetchEventDetail(String eventId);
}
