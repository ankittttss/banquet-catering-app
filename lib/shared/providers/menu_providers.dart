import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/menu_category.dart';
import '../../data/models/menu_item.dart';
import '../../data/models/restaurant.dart';
import 'address_providers.dart';
import 'filters_providers.dart';
import 'repositories_providers.dart';

final menuCategoriesProvider = FutureProvider<List<MenuCategory>>((ref) {
  return ref.read(menuRepositoryProvider).fetchCategories();
});

/// Home restaurant list. When the active address has coordinates, runs the
/// `restaurants_near` RPC so the list reorders by distance; otherwise shows
/// the full catalog. An empty nearby result is returned as-is (empty state)
/// so the user can tell their locality genuinely has no matches rather than
/// always seeing the full list.
final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final repo = ref.read(menuRepositoryProvider);
  final addr = ref.watch(activeAddressProvider);
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
