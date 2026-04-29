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
/// Precedence (most → least specific):
///   1. Event draft has a chosen tier → `restaurants_for_event` RPC, which
///      filters by the tier's per-guest budget band *and* (when coords are
///      available) a 25km radius around the event location.
///   2. Active address has coordinates → `restaurants_near` RPC, distance sort.
///   3. Otherwise → full catalog, popularity sort.
final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final repo = ref.read(menuRepositoryProvider);
  final addr = ref.watch(activeAddressProvider);
  final draft = ref.watch(eventDraftProvider);

  if (draft.tierId != null) {
    final tierRepo = ref.read(eventTierRepositoryProvider);
    return tierRepo.restaurantsForTier(
      tierId: draft.tierId!,
      latitude: addr?.latitude,
      longitude: addr?.longitude,
    );
  }

  if (addr != null && addr.hasCoords) {
    return repo.fetchNearby(
      latitude: addr.latitude!,
      longitude: addr.longitude!,
    );
  }
  return repo.fetchRestaurants();
});

final menuItemsProvider = FutureProvider<List<MenuItem>>((ref) {
  return ref.read(menuRepositoryProvider).fetchMenuItems();
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
