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
}
