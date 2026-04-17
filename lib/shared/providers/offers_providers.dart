import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/restaurant_offer.dart';
import 'repositories_providers.dart';

/// Offer cards for a given restaurant — shown at the top of the detail page.
final restaurantOffersProvider =
    FutureProvider.family<List<RestaurantOffer>, String>((ref, restaurantId) {
  return ref.read(taxonomyRepositoryProvider).fetchOffersFor(restaurantId);
});
