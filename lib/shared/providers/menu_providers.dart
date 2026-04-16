import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/menu_category.dart';
import '../../data/models/menu_item.dart';
import '../../data/models/restaurant.dart';
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

/// Menu items filtered by selected category.
final filteredMenuItemsProvider = Provider<AsyncValue<List<MenuItem>>>((ref) {
  final items = ref.watch(menuItemsProvider);
  final cat = ref.watch(selectedCategoryProvider);
  return items.whenData((list) {
    if (cat == null) return list;
    return list.where((i) => i.categoryId == cat).toList(growable: false);
  });
});
