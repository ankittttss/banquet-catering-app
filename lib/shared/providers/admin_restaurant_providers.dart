import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/menu_item.dart';
import '../../data/models/restaurant.dart';
import '../../data/repositories/admin_restaurant_repository.dart';
import 'repositories_providers.dart';

/// State + data providers for the admin restaurants console. Same style as
/// the home feed (StateProviders for filter inputs, FutureProvider for the
/// fetch): change an input and the list re-queries server-side.

/// Name search box text. Debounced at the widget layer before writing here.
final adminRestaurantSearchProvider = StateProvider<String>((_) => '');

/// Lifecycle filter chip. Null = all statuses.
final adminRestaurantStatusFilterProvider =
    StateProvider<RestaurantStatus?>((_) => null);

/// Zero-based page. Reset this whenever search/status change.
final adminRestaurantPageProvider = StateProvider<int>((_) => 0);

/// The current page of the admin restaurants list (server-side filtered —
/// the 1000+ row catalog is never fetched in full).
final adminRestaurantListProvider = FutureProvider<AdminRestaurantPage>((ref) {
  final repo = ref.watch(adminRestaurantRepositoryProvider);
  return repo.fetchPage(
    search: ref.watch(adminRestaurantSearchProvider),
    status: ref.watch(adminRestaurantStatusFilterProvider),
    page: ref.watch(adminRestaurantPageProvider),
  );
});

/// One restaurant by id, any lifecycle state — the management page and
/// wizard resume path. Null when the id doesn't exist (deleted?).
final adminRestaurantProvider =
    FutureProvider.family<Restaurant?, String>((ref, id) {
  return ref.watch(adminRestaurantRepositoryProvider).fetchById(id);
});

/// Full menu of one restaurant including unavailable items — the scoped
/// admin menu manager and the publish checklist.
///
/// After any admin write, screens invalidate the touched providers here plus
/// the customer-facing `restaurantsProvider` (so a publish shows up on the
/// home feed without an app restart) — same explicit-invalidation pattern
/// as the admin menu editor.
final adminRestaurantMenuProvider =
    FutureProvider.family<List<MenuItem>, String>((ref, restaurantId) {
  return ref
      .watch(adminRestaurantRepositoryProvider)
      .fetchAllItemsForRestaurant(restaurantId);
});
