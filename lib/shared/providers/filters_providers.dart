import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MenuSort { defaultOrder, priceAsc, priceDesc }

class MenuFilters {
  const MenuFilters({
    this.vegOnly = false,
    this.maxPrice = 500,
    this.sort = MenuSort.defaultOrder,
  });

  final bool vegOnly;
  final double maxPrice;
  final MenuSort sort;

  static const MenuFilters empty = MenuFilters();

  bool get isActive =>
      vegOnly || maxPrice < 500 || sort != MenuSort.defaultOrder;

  MenuFilters copyWith({bool? vegOnly, double? maxPrice, MenuSort? sort}) =>
      MenuFilters(
        vegOnly: vegOnly ?? this.vegOnly,
        maxPrice: maxPrice ?? this.maxPrice,
        sort: sort ?? this.sort,
      );
}

class MenuFiltersController extends Notifier<MenuFilters> {
  @override
  MenuFilters build() => MenuFilters.empty;

  void toggleVeg() => state = state.copyWith(vegOnly: !state.vegOnly);
  void setMaxPrice(double v) => state = state.copyWith(maxPrice: v);
  void setSort(MenuSort s) => state = state.copyWith(sort: s);
  void reset() => state = MenuFilters.empty;
}

final menuFiltersProvider =
    NotifierProvider<MenuFiltersController, MenuFilters>(
  MenuFiltersController.new,
);
