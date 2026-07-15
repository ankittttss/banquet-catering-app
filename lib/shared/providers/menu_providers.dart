import 'package:flutter_riverpod/flutter_riverpod.dart';

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
///      available) a 25km radius around the resolved location.
///   2. Coordinates available (event location, else saved address) →
///      `restaurants_near` RPC, distance sort.
///   3. Otherwise → full catalog, popularity sort.
final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final repo = ref.read(menuRepositoryProvider);
  final addr = ref.watch(activeAddressProvider);
  final draft = ref.watch(eventDraftProvider);

  // Prefer the event-location coordinates; fall back to the saved address.
  double? lat;
  double? lng;
  if (draft.hasEventCoords) {
    lat = draft.eventLatitude;
    lng = draft.eventLongitude;
  } else if (addr != null && addr.hasCoords) {
    lat = addr.latitude;
    lng = addr.longitude;
  }

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

/// Menu items filtered by selected category + global filters.
final filteredMenuItemsProvider = Provider<AsyncValue<List<MenuItem>>>((ref) {
  final items = ref.watch(menuItemsProvider);
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
