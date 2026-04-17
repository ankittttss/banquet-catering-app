import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/restaurant.dart';

/// Contract for reading the menu catalog (categories, restaurants, items).
/// Write operations belong on the admin side and aren't modelled here yet.
abstract interface class MenuRepository {
  Future<List<MenuCategory>> fetchCategories();
  Future<List<Restaurant>> fetchRestaurants();
  Future<List<MenuItem>> fetchMenuItems();
}
