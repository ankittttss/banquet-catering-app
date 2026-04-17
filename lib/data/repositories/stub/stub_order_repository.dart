import '../../models/cart_item.dart';
import '../../models/checkout_totals.dart';
import '../../models/event_draft.dart';
import '../../models/order.dart';
import '../order_repository.dart';

/// No-op stub — returns a fake order id, empty lists, no-op updates.
/// Used only when Supabase isn't configured (local UI dev mode).
class StubOrderRepository implements OrderRepository {
  @override
  Future<String> placeOrder({
    required String userId,
    required EventDraft event,
    required List<CartItem> cart,
    required CheckoutTotals totals,
  }) async {
    return 'local-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Stream<List<OrderSummary>> streamMyOrders(String userId) =>
      const Stream.empty();

  @override
  Future<List<OrderSummary>> fetchAll() async => const [];

  @override
  Future<void> updateStatus(String orderId, OrderStatus status) async {}
}
