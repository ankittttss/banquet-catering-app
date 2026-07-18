import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/geo.dart';
import '../../data/models/menu_category.dart';
import '../../data/models/menu_item.dart';
import '../../data/models/restaurant.dart';
import 'address_providers.dart';
import 'event_providers.dart';
import 'filters_providers.dart';
import 'repositories_providers.dart';

final menuCategoriesProvider = FutureProvider<List<MenuCategory>>((ref) {
  return ref.read(menuRepositoryProvider).fetchCategories();
});

/// Home restaurant list.
///
/// Restaurants are sorted nearest-first to the **event location** when the
/// user has chosen one (its coordinates live on the event draft). Only when
/// there is no event location do we fall back to the user's saved home/work
/// address — so a customer planning an event across town sees the kitchens
/// near the venue, not near their house.
///
/// Precedence (most → least specific):
///   1. Event draft has a chosen tier → `restaurants_for_event` RPC, which
///      filters by the tier's per-guest budget band *and* (when coords are
///      available) the service radius around the resolved location
///      (kServiceRadiusKm — matches the checkout serviceability guard).
///   2. Coordinates available (event location, else saved address) →
///      `restaurants_near` RPC, distance sort.
///   3. Otherwise → full catalog, popularity sort.
final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final repo = ref.read(menuRepositoryProvider);
  final addr = ref.watch(activeAddressProvider);
  final draft = ref.watch(eventDraftProvider);

  // Event coords first; saved address only when NOT planning. While planning
  // without coords, resolveSortOrigin returns (null, null) — an honest
  // popularity sort, never a silent fallback to the home address (the header
  // says "Event location", so sorting around home would be a lie).
  final origin = resolveSortOrigin(draft: draft, savedAddress: addr);
  final lat = origin.lat;
  final lng = origin.lng;

  if (draft.tierId != null) {
    final tierRepo = ref.read(eventTierRepositoryProvider);
    return tierRepo.restaurantsForTier(
      tierId: draft.tierId!,
      latitude: lat,
      longitude: lng,
    );
  }

  if (lat != null && lng != null) {
    return repo.fetchNearby(latitude: lat, longitude: lng);
  }
  return repo.fetchRestaurants();
});

final menuItemsProvider = FutureProvider<List<MenuItem>>((ref) {
  return ref.read(menuRepositoryProvider).fetchMenuItems();
});

/// One restaurant resolved directly by id, in ANY lifecycle state (null when
/// deleted). The detail screen's source of truth — unlike the location/tier
///-scoped [restaurantsProvider], this always finds the restaurant, letting
/// the screen show honest "unavailable" / "out of range" states instead of
/// a blank shell.
final restaurantByIdProvider =
    FutureProvider.family<Restaurant?, String>((ref, id) {
  return ref.read(menuRepositoryProvider).fetchRestaurantById(id);
});

/// Admin catalog view — every menu item including unavailable ones. Distinct
/// from [menuItemsProvider], which hides unavailable rows for the storefront.
final adminMenuItemsProvider = FutureProvider<List<MenuItem>>((ref) {
  return ref.read(menuRepositoryProvider).fetchAllMenuItems();
});

/// Menu items for a single restaurant — avoids the 1000-row PostgREST cap
/// hit by the all-items [menuItemsProvider].
final restaurantMenuItemsProvider =
    FutureProvider.family<List<MenuItem>, String>((ref, restaurantId) {
  return ref
      .read(menuRepositoryProvider)
      .fetchMenuItemsForRestaurant(restaurantId);
});

/// Currently-selected category id on the menu screen. null = "all".
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Menu items belonging to the restaurants currently in the customer's
/// scope (location/tier-filtered [restaurantsProvider]). Replaces the old
/// whole-catalog fetch on the browse-dishes screen, which downloaded 20k+
/// rows and showed dishes from kitchens outside the customer's area.
final scopedMenuItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  final restaurants = await ref.watch(restaurantsProvider.future);
  final ids = restaurants.map((r) => r.id).toSet();
  if (ids.isEmpty) return const [];
  return ref.read(menuRepositoryProvider).fetchMenuItemsForRestaurants(ids);
});

/// Menu items filtered by selected category + global filters.
final filteredMenuItemsProvider = Provider<AsyncValue<List<MenuItem>>>((ref) {
  final items = ref.watch(scopedMenuItemsProvider);
  final cat = ref.watch(selectedCategoryProvider);
  final filters = ref.watch(menuFiltersProvider);
  return items.whenData((list) {
    Iterable<MenuItem> r = list;
    if (cat != null) r = r.where((i) => i.categoryId == cat);
    if (filters.vegOnly) r = r.where((i) => i.isVeg);
    r = r.where((i) => i.price <= filters.maxPrice);
    final out = r.toList(growable: false);
    switch (filters.sort) {
      case MenuSort.priceAsc:
        out.sort((a, b) => a.price.compareTo(b.price));
      case MenuSort.priceDesc:
        out.sort((a, b) => b.price.compareTo(a.price));
      case MenuSort.defaultOrder:
        break;
    }
    return out;
  });
});
