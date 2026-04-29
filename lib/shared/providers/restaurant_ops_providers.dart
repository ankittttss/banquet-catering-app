import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order_vendor_lot.dart';
import '../../data/models/restaurant.dart';
import 'repositories_providers.dart';

final myRestaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final repo = ref.watch(restaurantOpsRepositoryProvider);
  return repo.fetchMyRestaurants();
});

final myVendorLotsProvider =
    StreamProvider<List<OrderVendorLot>>((ref) async* {
  final repo = ref.watch(restaurantOpsRepositoryProvider);
  yield* repo.streamMyLots();
});
