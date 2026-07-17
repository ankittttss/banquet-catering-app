import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/dish_search_result.dart';
import '../../data/models/restaurant.dart';
import 'address_providers.dart';
import 'event_providers.dart';
import 'repositories_providers.dart';

/// Committed search text. The search screen debounces keystrokes (~350 ms)
/// before writing here, so each write costs one server round-trip.
final searchQueryProvider = StateProvider<String>((_) => '');

/// The customer's reference point, with the same precedence the home feed
/// uses (menu_providers.restaurantsProvider): event-location coords first,
/// then the active saved address. (null, null) when neither has coords —
/// search still works, results just carry no distance.
final customerCoordsProvider = Provider<({double? lat, double? lng})>((ref) {
  final draft = ref.watch(eventDraftProvider);
  if (draft.hasEventCoords) {
    return (lat: draft.eventLatitude, lng: draft.eventLongitude);
  }
  final addr = ref.watch(activeAddressProvider);
  if (addr != null && addr.hasCoords) {
    return (lat: addr.latitude, lng: addr.longitude);
  }
  return (lat: null, lng: null);
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
