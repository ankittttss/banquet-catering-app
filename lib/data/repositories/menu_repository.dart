import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/restaurant.dart';

/// Contract for the menu catalog (categories, restaurants, items). Read
/// methods power the customer storefront; the write methods at the bottom
/// back the admin "Menu & restaurants" editor.
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

  // ── Admin catalog editing ───────────────────────────────────────────────
  // These require the signed-in user to be an admin at the database level
  // (RLS insert/update/delete policies on `menu_items`).

  /// All menu items including unavailable ones — the admin catalog view.
  /// (The customer-facing [fetchMenuItems] hides unavailable rows.)
  Future<List<MenuItem>> fetchAllMenuItems();

  /// Insert a new menu item. The id is assigned by the backend.
  Future<void> createMenuItem({
    required String restaurantId,
    required String categoryId,
    required String name,
    required double price,
    String? description,
    bool isVeg = true,
    bool isAvailable = true,
  });

  /// Overwrite an existing item's editable fields (matched by [MenuItem.id]).
  Future<void> updateMenuItem(MenuItem item);

  /// Flip just the availability flag — backs the per-row toggle.
  Future<void> setMenuItemAvailability({
    required String id,
    required bool isAvailable,
  });

  /// Permanently remove a menu item.
  Future<void> deleteMenuItem(String id);
}
