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

  /// Aggregated event-level snapshot used by the manager event-detail
  /// screen: event row + venue/tier names + the booking order + per-
  /// restaurant vendor lots in a single query. Returns `null` when the
  /// event id doesn't exist.
  Future<ManagerEventDetail?> fetchEventDetail(String eventId);
}
