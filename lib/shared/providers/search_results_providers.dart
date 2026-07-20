import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/geo.dart';
import '../../data/models/dish_search_result.dart';
import '../../data/models/restaurant.dart';
import 'address_providers.dart';
import 'event_providers.dart';
import 'repositories_providers.dart';

/// Committed search text. The search screen debounces keystrokes (~350 ms)
/// before writing here, so each write costs one server round-trip.
final searchQueryProvider = StateProvider<String>((_) => '');

/// The customer's reference point — THE single location rule for every
/// customer flow (home feed, search distances, restaurant-detail and cart
/// serviceability, checkout revalidation), all via [resolveSortOrigin]:
/// event coords first; while PLANNING without coords → (null, null), never
/// the home address (serviceability then reads `unknown`, which never
/// blocks browsing — checkout + place_order enforce the hard stop);
/// home-address coords only when no event is being planned.
final customerCoordsProvider = Provider<({double? lat, double? lng})>((ref) {
  final draft = ref.watch(eventDraftProvider);
  final addr = ref.watch(activeAddressProvider);
  return resolveSortOrigin(draft: draft, savedAddress: addr);
});

/// Server-side restaurant search over the WHOLE published catalog — no
/// radius filter. Out-of-range kitchens come back with a distance so the
/// UI labels them instead of hiding them. Re-fires automatically when the
/// query, the active address, or the event location changes.
final restaurantSearchProvider =
    FutureProvider.autoDispose<List<Restaurant>>((ref) {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.length < 2) return Future.value(const []);
  final coords = ref.watch(customerCoordsProvider);
  return ref.read(menuRepositoryProvider).searchRestaurants(
        q,
        latitude: coords.lat,
        longitude: coords.lng,
      );
});

/// Server-side dish search — every result is joined to its live restaurant,
/// so rows always carry a real restaurant name and are always tappable.
final dishSearchProvider =
    FutureProvider.autoDispose<List<DishSearchResult>>((ref) {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.length < 2) return Future.value(const []);
  final coords = ref.watch(customerCoordsProvider);
  return ref.read(menuRepositoryProvider).searchDishes(
        q,
        latitude: coords.lat,
        longitude: coords.lng,
      );
});
