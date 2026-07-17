import 'dart:typed_data';

import '../models/dish_search_result.dart';
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

  /// Available menu items belonging to the given restaurants — powers the
  /// browse-dishes screen scoped to the customer's current restaurant list
  /// instead of downloading the entire 20k+ item catalog.
  Future<List<MenuItem>> fetchMenuItemsForRestaurants(Set<String> ids);

  /// Of the given restaurant ids, the ones customers can NOT order from
  /// right now — unpublished (draft/suspended/archived) or deleted. Backs
  /// the checkout guard: a restaurant can be taken offline by the admin
  /// while its items sit in a customer's cart.
  Future<Set<String>> fetchInactiveRestaurantIds(Set<String> ids);

  // ── Customer search & by-id resolution ──────────────────────────────────

  /// Every PUBLISHED restaurant matching [query] by name or cuisine — no
  /// radius filter, so out-of-range kitchens are found and labeled instead
  /// of hidden. Results carry [Restaurant.distanceKm] when coords are given.
  Future<List<Restaurant>> searchRestaurants(
    String query, {
    double? latitude,
    double? longitude,
  });

  /// Available dishes matching [query] by name/description, each joined to
  /// its live restaurant (dishes of hidden restaurants never surface).
  Future<List<DishSearchResult>> searchDishes(
    String query, {
    double? latitude,
    double? longitude,
  });

  /// One restaurant by id in ANY lifecycle state, or null when it no longer
  /// exists. Lets the detail screen distinguish "unavailable" from "blank".
  Future<Restaurant?> fetchRestaurantById(String id);

  /// The given restaurants in ANY lifecycle state — resolves cart lines and
  /// favorites without depending on the location-scoped home list.
  Future<List<Restaurant>> fetchRestaurantsByIds(Set<String> ids);

  /// Of the given menu-item ids, the ones that are no longer orderable
  /// (toggled unavailable or deleted). Backs the checkout guard.
  Future<Set<String>> fetchUnavailableItemIds(Set<String> ids);

  /// Current price of each still-orderable item id → price. Missing ids
  /// (deleted/unavailable) are omitted. Backs the checkout price re-check so
  /// a customer is never billed a stale cart-snapshot price.
  Future<Map<String, double>> fetchItemPrices(Set<String> ids);

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
    String? imageUrl,
    bool isVeg = true,
    bool isAvailable = true,
  });

  /// Overwrite an existing item's editable fields (matched by [MenuItem.id]),
  /// including its [MenuItem.imageUrl].
  Future<void> updateMenuItem(MenuItem item);

  /// Uploads a dish photo to the `menu-images` bucket (admin only) and returns
  /// its public URL. Path is keyed on the restaurant, not the item, so it can
  /// be called before the item row exists.
  Future<String> uploadMenuItemImage({
    required String restaurantId,
    required Uint8List bytes,
  });

  /// Flip just the availability flag — backs the per-row toggle.
  Future<void> setMenuItemAvailability({
    required String id,
    required bool isAvailable,
  });

  /// Remove a menu item. Items that have been ordered are soft-deleted
  /// (hidden from the catalog but kept so order history + the RESTRICT FK on
  /// order_items stay intact); never-ordered items may be removed outright.
  Future<void> deleteMenuItem(String id);
}
