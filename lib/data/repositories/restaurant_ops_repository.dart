import '../models/order_vendor_lot.dart';
import '../models/restaurant.dart';

/// Restaurant-operator view: list of kitchens I own, vendor lots routed to
/// those kitchens, and the status transitions I'm allowed to make.
abstract interface class RestaurantOpsRepository {
  /// Restaurants the current user is listed as staff for.
  Future<List<Restaurant>> fetchMyRestaurants();

  /// Vendor lots routed to any restaurant the user owns.
  /// Ordered by createdAt desc. Joined with restaurant name for display.
  Future<List<OrderVendorLot>> fetchMyLots();
  Stream<List<OrderVendorLot>> streamMyLots();

  Future<void> updateLotStatus({
    required String lotId,
    required VendorLotStatus status,
  });
}
