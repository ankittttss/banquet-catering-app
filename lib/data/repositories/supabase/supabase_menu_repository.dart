import '../../../core/supabase/supabase_client.dart';
import '../../models/menu_category.dart';
import '../../models/menu_item.dart';
import '../../models/restaurant.dart';
import '../menu_repository.dart';

class SupabaseMenuRepository implements MenuRepository {
  @override
  Future<List<MenuCategory>> fetchCategories() async {
    final rows = await supabase
        .from('menu_categories')
        .select()
        .order('sort_order', ascending: true);
    return rows
        .map<MenuCategory>(MenuCategory.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<Restaurant>> fetchRestaurants() async {
    final rows = await supabase
        .from('restaurants')
        .select()
        .eq('is_active', true)
        .order('popularity_score', ascending: false)
        .order('name');
    return rows.map<Restaurant>(Restaurant.fromMap).toList(growable: false);
  }

  @override
  Future<List<Restaurant>> fetchNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    final rows = await supabase.rpc('restaurants_near', params: {
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_radius_km': radiusKm,
    });
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map<Restaurant>(Restaurant.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<MenuItem>> fetchMenuItems() async {
    // Paginated fetch — PostgREST caps single responses at 1000 rows.
    final all = <MenuItem>[];
    const pageSize = 1000;
    for (var offset = 0;; offset += pageSize) {
      final rows = await supabase
          .from('menu_items')
          .select()
          .eq('is_available', true)
          .order('name')
          .range(offset, offset + pageSize - 1);
      all.addAll(rows.map<MenuItem>(MenuItem.fromMap));
      if (rows.length < pageSize) break;
    }
    return all;
  }

  @override
  Future<List<MenuItem>> fetchMenuItemsForRestaurant(String restaurantId) async {
    final rows = await supabase
        .from('menu_items')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_available', true)
        .order('name');
    return rows.map<MenuItem>(MenuItem.fromMap).toList(growable: false);
  }

  // ── Admin catalog editing ───────────────────────────────────────────────

  @override
  Future<List<MenuItem>> fetchAllMenuItems() async {
    // Like [fetchMenuItems] but WITHOUT the is_available filter, so the admin
    // can see and re-enable disabled items. Paginated for the 1000-row cap.
    final all = <MenuItem>[];
    const pageSize = 1000;
    for (var offset = 0;; offset += pageSize) {
      final rows = await supabase
          .from('menu_items')
          .select()
          .order('name')
          .range(offset, offset + pageSize - 1);
      all.addAll(rows.map<MenuItem>(MenuItem.fromMap));
      if (rows.length < pageSize) break;
    }
    return all;
  }

  @override
  Future<void> createMenuItem({
    required String restaurantId,
    required String categoryId,
    required String name,
    required double price,
    String? description,
    bool isVeg = true,
    bool isAvailable = true,
  }) async {
    final desc = description?.trim();
    await supabase.from('menu_items').insert({
      'restaurant_id': restaurantId,
      'category_id': categoryId,
      'name': name.trim(),
      'price': price,
      if (desc != null && desc.isNotEmpty) 'description': desc,
      'is_veg': isVeg,
      'is_available': isAvailable,
    });
  }

  @override
  Future<void> updateMenuItem(MenuItem item) async {
    final desc = item.description?.trim();
    await supabase.from('menu_items').update({
      'restaurant_id': item.restaurantId,
      'category_id': item.categoryId,
      'name': item.name.trim(),
      'price': item.price,
      'description': (desc != null && desc.isNotEmpty) ? desc : null,
      'is_veg': item.isVeg,
      'is_available': item.isAvailable,
    }).eq('id', item.id);
  }

  @override
  Future<void> setMenuItemAvailability({
    required String id,
    required bool isAvailable,
  }) async {
    await supabase
        .from('menu_items')
        .update({'is_available': isAvailable}).eq('id', id);
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    await supabase.from('menu_items').delete().eq('id', id);
  }
}
