import '../../models/order_vendor_lot.dart';
import '../../models/restaurant.dart';
import '../restaurant_ops_repository.dart';

class StubRestaurantOpsRepository implements RestaurantOpsRepository {
  @override
  Future<List<Restaurant>> fetchMyRestaurants() async => const [];

  @override
  Future<List<OrderVendorLot>> fetchMyLots() async => const [];

  @override
  Stream<List<OrderVendorLot>> streamMyLots() async* {
    yield const [];
  }

  @override
  Future<void> updateLotStatus({
    required String lotId,
    required VendorLotStatus status,
  }) async {}
}
