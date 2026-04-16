import '../../core/config/app_config.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/restaurant.dart';

class MenuRepository {
  MenuRepository();

  Future<List<MenuCategory>> fetchCategories() async {
    if (!AppConfig.hasSupabase) return _stubCategories;
    final rows = await supabase
        .from('menu_categories')
        .select()
        .order('sort_order', ascending: true);
    return rows
        .map<MenuCategory>((r) => MenuCategory.fromMap(r))
        .toList(growable: false);
  }

  Future<List<Restaurant>> fetchRestaurants() async {
    if (!AppConfig.hasSupabase) return _stubRestaurants;
    final rows = await supabase
        .from('restaurants')
        .select()
        .eq('is_active', true)
        .order('name');
    return rows
        .map<Restaurant>((r) => Restaurant.fromMap(r))
        .toList(growable: false);
  }

  Future<List<MenuItem>> fetchMenuItems() async {
    if (!AppConfig.hasSupabase) return _stubMenuItems;
    final rows = await supabase
        .from('menu_items')
        .select()
        .eq('is_available', true)
        .order('name');
    return rows
        .map<MenuItem>((r) => MenuItem.fromMap(r))
        .toList(growable: false);
  }

  // --- local dev fallback data ---

  static const _stubCategories = [
    MenuCategory(id: 'c1', name: 'Welcome Drinks', sortOrder: 1),
    MenuCategory(id: 'c2', name: 'Starters', sortOrder: 2),
    MenuCategory(id: 'c3', name: 'Main Course', sortOrder: 3),
    MenuCategory(id: 'c4', name: 'Desserts', sortOrder: 4),
    MenuCategory(id: 'c5', name: 'Additional', sortOrder: 5),
  ];

  static const _stubRestaurants = [
    Restaurant(
        id: 'r1',
        name: 'Spice Route Catering',
        deliveryCharge: 1200,
        logoUrl: null),
    Restaurant(
        id: 'r2',
        name: 'Royal Banquet Kitchen',
        deliveryCharge: 1500,
        logoUrl: null),
  ];

  static const _stubMenuItems = [
    // r1 — welcome drinks
    MenuItem(
        id: 'i1',
        restaurantId: 'r1',
        categoryId: 'c1',
        name: 'Masala Lemonade',
        price: 80),
    MenuItem(
        id: 'i2',
        restaurantId: 'r1',
        categoryId: 'c1',
        name: 'Rose Sharbat',
        price: 90),
    // r1 — starters
    MenuItem(
        id: 'i3',
        restaurantId: 'r1',
        categoryId: 'c2',
        name: 'Paneer Tikka',
        price: 220),
    MenuItem(
        id: 'i4',
        restaurantId: 'r1',
        categoryId: 'c2',
        name: 'Murg Malai Kebab',
        price: 260,
        isVeg: false),
    // r1 — main
    MenuItem(
        id: 'i5',
        restaurantId: 'r1',
        categoryId: 'c3',
        name: 'Dal Makhani',
        price: 180),
    MenuItem(
        id: 'i6',
        restaurantId: 'r1',
        categoryId: 'c3',
        name: 'Hyderabadi Biryani',
        price: 240,
        isVeg: false),
    // r1 — desserts
    MenuItem(
        id: 'i7',
        restaurantId: 'r1',
        categoryId: 'c4',
        name: 'Gulab Jamun',
        price: 90),

    // r2 — welcome drinks
    MenuItem(
        id: 'i8',
        restaurantId: 'r2',
        categoryId: 'c1',
        name: 'Coconut Cooler',
        price: 100),
    // r2 — main
    MenuItem(
        id: 'i9',
        restaurantId: 'r2',
        categoryId: 'c3',
        name: 'Kashmiri Rogan Josh',
        price: 320,
        isVeg: false),
    MenuItem(
        id: 'i10',
        restaurantId: 'r2',
        categoryId: 'c3',
        name: 'Paneer Butter Masala',
        price: 220),
    // r2 — desserts
    MenuItem(
        id: 'i11',
        restaurantId: 'r2',
        categoryId: 'c4',
        name: 'Rasmalai',
        price: 110),
    // r2 — additional
    MenuItem(
        id: 'i12',
        restaurantId: 'r2',
        categoryId: 'c5',
        name: 'Pickle & Papad Platter',
        price: 60),
  ];
}
