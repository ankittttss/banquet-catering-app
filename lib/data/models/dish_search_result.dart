import 'menu_item.dart';

/// One row from the `search_menu_items` RPC: a dish joined to its (live)
/// restaurant, so search results always carry a real restaurant name.
class DishSearchResult {
  const DishSearchResult({
    required this.item,
    required this.restaurantName,
    this.distanceKm,
  });

  final MenuItem item;
  final String restaurantName;

  /// Restaurant's distance from the customer. Null when the customer has no
  /// location set.
  final double? distanceKm;

  factory DishSearchResult.fromMap(Map<String, dynamic> map) =>
      DishSearchResult(
        // The RPC row uses the same column names as menu_items.
        item: MenuItem.fromMap(map),
        restaurantName: (map['restaurant_name'] as String?) ?? 'Restaurant',
        distanceKm: (map['distance_km'] as num?)?.toDouble(),
      );
}
