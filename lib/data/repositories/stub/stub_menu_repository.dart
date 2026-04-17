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
    Restaurant(
      id: 'r1',
      name: 'Spice Route Catering',
      logoUrl:
          'https://images.unsplash.com/photo-1546241072-48010ad2862c?w=600&q=80&auto=format&fit=crop',
      deliveryCharge: 1200,
      pricePerPlate: 300,
      minGuests: 5,
      deliveryMinMinutes: 30,
      deliveryMaxMinutes: 40,
      rating: 4.5,
      ratingsCount: 12400,
      cuisinesDisplay: 'Biryani · North Indian · Mughlai',
      heroBgHex: '#FFF3E0',
      heroEmoji: '🍛',
      tag: 'Bestseller',
      popularityScore: 100,
    ),
    Restaurant(
      id: 'r2',
      name: 'Royal Banquet Kitchen',
      logoUrl:
          'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&q=80&auto=format&fit=crop',
      deliveryCharge: 1500,
      pricePerPlate: 250,
      minGuests: 20,
      deliveryMinMinutes: 45,
      deliveryMaxMinutes: 60,
      rating: 4.3,
      ratingsCount: 3200,
      cuisinesDisplay: 'Multi-cuisine · Buffet · Catering',
      heroBgHex: '#EDE7F6',
      heroEmoji: '🥘',
      tag: 'Event Special',
      popularityScore: 90,
    ),
    Restaurant(
      id: 'r3',
      name: 'Coastal Kitchen',
      logoUrl:
          'https://images.unsplash.com/photo-1595329083003-47e40ec25e05?w=600&q=80&auto=format&fit=crop',
      deliveryCharge: 1400,
      pricePerPlate: 200,
      minGuests: 10,
      deliveryMinMinutes: 35,
      deliveryMaxMinutes: 50,
      rating: 4.7,
      ratingsCount: 8900,
      cuisinesDisplay: 'South Indian · Thali · Andhra',
      heroBgHex: '#E8F5E9',
      heroEmoji: '🥥',
      tag: 'Pure Veg',
      isPureVeg: true,
      popularityScore: 85,
    ),
    Restaurant(
      id: 'r4',
      name: 'Maharaj Rasoi',
      logoUrl:
          'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&q=80&auto=format&fit=crop',
      deliveryCharge: 1300,
      pricePerPlate: 280,
      minGuests: 15,
      deliveryMinMinutes: 40,
      deliveryMaxMinutes: 55,
      rating: 4.4,
      ratingsCount: 2100,
      cuisinesDisplay: 'Rajasthani · Thali · Traditional',
      heroBgHex: '#FFF8E1',
      heroEmoji: '🪔',
      tag: 'Royal Thali',
      popularityScore: 70,
    ),
    Restaurant(
      id: 'r5',
      name: 'Delhi Darbar Catering',
      logoUrl:
          'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600&q=80&auto=format&fit=crop',
      deliveryCharge: 1500,
      pricePerPlate: 320,
      minGuests: 15,
      deliveryMinMinutes: 40,
      deliveryMaxMinutes: 55,
      rating: 4.2,
      ratingsCount: 1800,
      cuisinesDisplay: 'North Indian · Mughlai · Tandoor',
      heroBgHex: '#FFEBEE',
      heroEmoji: '🍗',
      tag: 'Tandoor Special',
      popularityScore: 65,
    ),
    Restaurant(
      id: 'r6',
      name: 'Sattvik Events',
      logoUrl:
          'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&q=80&auto=format&fit=crop',
      deliveryCharge: 1100,
      pricePerPlate: 220,
      minGuests: 10,
      deliveryMinMinutes: 35,
      deliveryMaxMinutes: 50,
      rating: 4.6,
      ratingsCount: 1500,
      cuisinesDisplay: 'Sattvik · Pure Veg · Jain',
      heroBgHex: '#E8F5E9',
      heroEmoji: '🪷',
      tag: 'Pure Veg',
      isPureVeg: true,
      popularityScore: 60,
    ),
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
