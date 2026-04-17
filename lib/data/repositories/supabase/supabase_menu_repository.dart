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
  Future<List<MenuItem>> fetchMenuItems() async {
    final rows = await supabase
        .from('menu_items')
        .select()
        .eq('is_available', true)
        .order('name');
    return rows.map<MenuItem>(MenuItem.fromMap).toList(growable: false);
  }
}
