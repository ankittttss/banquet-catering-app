import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/restaurant.dart';

/// Contract for reading the menu catalog (categories, restaurants, items).
/// Write operations belong on the admin side and aren't modelled here yet.
abstract interface class MenuRepository {
  Future<List<MenuCategory>> fetchCategories();
  Future<List<Restaurant>> fetchRestaurants();

  /// Restaurants within [radiusKm] of the given point, ordered by distance.
  /// When the backend hasn't been configured with PostGIS or no rows have
  /// coordinates yet, implementations should fall back to [fetchRestaurants].
  Future<List<Restaurant>> fetchNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  });

  Future<List<MenuItem>> fetchMenuItems();

  /// Menu items belonging to a specific restaurant. Cheaper than loading
  /// the whole catalog on restaurant-detail screens and avoids hitting
  /// the 1000-row PostgREST cap.
  Future<List<MenuItem>> fetchMenuItemsForRestaurant(String restaurantId);
}
