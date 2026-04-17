import '../models/cart_item.dart';
import '../models/checkout_totals.dart';
import '../models/event_draft.dart';
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
}
