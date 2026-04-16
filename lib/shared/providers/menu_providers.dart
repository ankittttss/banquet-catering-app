import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/menu_category.dart';
import '../../data/models/menu_item.dart';
import '../../data/models/restaurant.dart';
import 'filters_providers.dart';
import 'repositories_providers.dart';

final menuCategoriesProvider = FutureProvider<List<MenuCategory>>((ref) {
  return ref.read(menuRepositoryProvider).fetchCategories();
});

final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) {
  return ref.read(menuRepositoryProvider).fetchRestaurants();
});

final menuItemsProvider = FutureProvider<List<MenuItem>>((ref) {
  return ref.read(menuRepositoryProvider).fetchMenuItems();
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
