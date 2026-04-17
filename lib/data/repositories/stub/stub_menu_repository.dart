import '../../models/menu_category.dart';
import '../../models/menu_item.dart';
import '../../models/restaurant.dart';
import '../menu_repository.dart';

/// In-memory menu for local UI dev when Supabase isn't configured.
/// Mirrors the shape of what `seed_data.sql` seeds, just smaller.
class StubMenuRepository implements MenuRepository {
  @override
  Future<List<MenuCategory>> fetchCategories() async => _categories;

  @override
  Future<List<Restaurant>> fetchRestaurants() async => _restaurants;

  @override
  Future<List<MenuItem>> fetchMenuItems() async => _items;

  static const _categories = [
    MenuCategory(id: 'c1', name: 'Welcome Drinks', sortOrder: 1),
    MenuCategory(id: 'c2', name: 'Starters', sortOrder: 2),
    MenuCategory(id: 'c3', name: 'Main Course', sortOrder: 3),
    MenuCategory(id: 'c4', name: 'Desserts', sortOrder: 4),
    MenuCategory(id: 'c5', name: 'Additional', sortOrder: 5),
  ];

  static const _restaurants = [
    Restaurant(id: 'r1', name: 'Spice Route Catering', deliveryCharge: 1200),
    Restaurant(id: 'r2', name: 'Royal Banquet Kitchen', deliveryCharge: 1500),
    Restaurant(id: 'r3', name: 'Coastal Kitchen', deliveryCharge: 1400),
  ];

  static const _items = [
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
    MenuItem(
        id: 'i7',
        restaurantId: 'r1',
        categoryId: 'c4',
        name: 'Gulab Jamun',
        price: 90),
    MenuItem(
        id: 'i8',
        restaurantId: 'r2',
        categoryId: 'c1',
        name: 'Coconut Cooler',
        price: 100),
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
    MenuItem(
        id: 'i11',
        restaurantId: 'r2',
        categoryId: 'c4',
        name: 'Rasmalai',
        price: 110),
    MenuItem(
        id: 'i12',
        restaurantId: 'r3',
        categoryId: 'c5',
        name: 'Pickle & Papad Platter',
        price: 60),
  ];
}
