import 'dart:typed_data';

import '../../models/dish_search_result.dart';
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
  Future<List<Restaurant>> fetchRestaurants() async =>
      // Customer path — lifecycle-aware like the Supabase impl's is_active
      // filter: drafts/suspended/archived stay hidden.
      _restaurants.where((r) => r.isActive).toList(growable: false);

  @override
  Future<List<Restaurant>> fetchNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) =>
      fetchRestaurants(); // Stub: ignore geo, return full active catalog.

  /// Shared in-memory stores. [StubAdminRestaurantRepository] mutates these
  /// directly so admin onboarding/edits show up in the customer stub flows
  /// within the same session — mirroring how both Supabase repos share the
  /// same tables.
  List<Restaurant> get restaurantStore => _restaurants;
  List<MenuItem> get itemStore => _items;

  @override
  Future<Set<String>> fetchInactiveRestaurantIds(Set<String> ids) async {
    final active = _restaurants
        .where((r) => r.isActive && ids.contains(r.id))
        .map((r) => r.id)
        .toSet();
    return ids.difference(active);
  }

  // ── Customer search & by-id resolution ──────────────────────────────────

  @override
  Future<List<Restaurant>> searchRestaurants(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    return _restaurants
        .where((r) => r.isActive)
        .where(
          (r) =>
              r.name.toLowerCase().contains(q) ||
              (r.cuisinesDisplay?.toLowerCase().contains(q) ?? false),
        )
        .toList(growable: false);
  }

  @override
  Future<List<DishSearchResult>> searchDishes(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    final activeIds =
        _restaurants.where((r) => r.isActive).map((r) => r.id).toSet();
    return _items
        .where((i) => i.isAvailable && activeIds.contains(i.restaurantId))
        .where(
          (i) =>
              i.name.toLowerCase().contains(q) ||
              (i.description?.toLowerCase().contains(q) ?? false),
        )
        .map(
          (i) => DishSearchResult(
            item: i,
            restaurantName:
                _restaurants.firstWhere((r) => r.id == i.restaurantId).name,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Restaurant?> fetchRestaurantById(String id) async {
    for (final r in _restaurants) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<List<Restaurant>> fetchRestaurantsByIds(Set<String> ids) async =>
      _restaurants.where((r) => ids.contains(r.id)).toList(growable: false);

  @override
  Future<Set<String>> fetchUnavailableItemIds(Set<String> ids) async {
    final available = _items
        .where((i) => i.isAvailable && ids.contains(i.id))
        .map((i) => i.id)
        .toSet();
    return ids.difference(available);
  }

  @override
  Future<Map<String, double>> fetchItemPrices(Set<String> ids) async => {
        for (final i in _items)
          if (i.isAvailable && ids.contains(i.id)) i.id: i.price,
      };

  @override
  Future<List<MenuItem>> fetchMenuItems() async => _items;

  @override
  Future<List<MenuItem>> fetchMenuItemsForRestaurant(
    String restaurantId,
  ) async =>
      _items.where((i) => i.restaurantId == restaurantId).toList();

  @override
  Future<List<MenuItem>> fetchMenuItemsForRestaurants(Set<String> ids) async =>
      _items
          .where((i) => i.isAvailable && ids.contains(i.restaurantId))
          .toList(growable: false);

  // ── Admin catalog editing (in-memory; persists for the session) ─────────

  var _idSeq = 100;

  @override
  Future<List<MenuItem>> fetchAllMenuItems() async => List.of(_items);

  @override
  Future<void> createMenuItem({
    required String restaurantId,
    required String categoryId,
    required String name,
    required double price,
    String? description,
    String? imageUrl,
    bool isVeg = true,
    bool isAvailable = true,
  }) async {
    _items.add(
      MenuItem(
        id: 'i${++_idSeq}',
        restaurantId: restaurantId,
        categoryId: categoryId,
        name: name.trim(),
        price: price,
        description: description?.trim(),
        imageUrl: imageUrl,
        isVeg: isVeg,
        isAvailable: isAvailable,
      ),
    );
  }

  @override
  Future<void> updateMenuItem(MenuItem item) async {
    final i = _items.indexWhere((m) => m.id == item.id);
    if (i != -1) _items[i] = item;
  }

  @override
  Future<String> uploadMenuItemImage({
    required String restaurantId,
    required Uint8List bytes,
  }) async =>
      // Offline mode can't host bytes — return a placeholder so the form flow
      // still works end-to-end.
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80&auto=format&fit=crop';

  @override
  Future<void> setMenuItemAvailability({
    required String id,
    required bool isAvailable,
  }) async {
    final i = _items.indexWhere((m) => m.id == id);
    if (i == -1) return;
    final o = _items[i];
    _items[i] = MenuItem(
      id: o.id,
      restaurantId: o.restaurantId,
      categoryId: o.categoryId,
      name: o.name,
      price: o.price,
      description: o.description,
      imageUrl: o.imageUrl,
      isVeg: o.isVeg,
      isAvailable: isAvailable,
    );
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    _items.removeWhere((m) => m.id == id);
  }

  static const _categories = [
    MenuCategory(id: 'c1', name: 'Welcome Drinks', sortOrder: 1),
    MenuCategory(id: 'c2', name: 'Starters', sortOrder: 2),
    MenuCategory(id: 'c3', name: 'Main Course', sortOrder: 3),
    MenuCategory(id: 'c4', name: 'Desserts', sortOrder: 4),
    MenuCategory(id: 'c5', name: 'Additional', sortOrder: 5),
  ];

  // Growable (not const): the admin stub onboards/edits rows in place.
  final List<Restaurant> _restaurants = [
    const Restaurant(
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
    const Restaurant(
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
    const Restaurant(
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
    const Restaurant(
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
    const Restaurant(
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
    const Restaurant(
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

  final List<MenuItem> _items = [
    const MenuItem(
        id: 'i1',
        restaurantId: 'r1',
        categoryId: 'c1',
        name: 'Masala Lemonade',
        price: 80),
    const MenuItem(
        id: 'i2',
        restaurantId: 'r1',
        categoryId: 'c1',
        name: 'Rose Sharbat',
        price: 90),
    const MenuItem(
        id: 'i3',
        restaurantId: 'r1',
        categoryId: 'c2',
        name: 'Paneer Tikka',
        price: 220),
    const MenuItem(
        id: 'i4',
        restaurantId: 'r1',
        categoryId: 'c2',
        name: 'Murg Malai Kebab',
        price: 260,
        isVeg: false),
    const MenuItem(
        id: 'i5',
        restaurantId: 'r1',
        categoryId: 'c3',
        name: 'Dal Makhani',
        price: 180),
    const MenuItem(
        id: 'i6',
        restaurantId: 'r1',
        categoryId: 'c3',
        name: 'Hyderabadi Biryani',
        price: 240,
        isVeg: false),
    const MenuItem(
        id: 'i7',
        restaurantId: 'r1',
        categoryId: 'c4',
        name: 'Gulab Jamun',
        price: 90),
    const MenuItem(
        id: 'i8',
        restaurantId: 'r2',
        categoryId: 'c1',
        name: 'Coconut Cooler',
        price: 100),
    const MenuItem(
        id: 'i9',
        restaurantId: 'r2',
        categoryId: 'c3',
        name: 'Kashmiri Rogan Josh',
        price: 320,
        isVeg: false),
    const MenuItem(
        id: 'i10',
        restaurantId: 'r2',
        categoryId: 'c3',
        name: 'Paneer Butter Masala',
        price: 220),
    const MenuItem(
        id: 'i11',
        restaurantId: 'r2',
        categoryId: 'c4',
        name: 'Rasmalai',
        price: 110),
    const MenuItem(
        id: 'i12',
        restaurantId: 'r3',
        categoryId: 'c5',
        name: 'Pickle & Papad Platter',
        price: 60),
  ];
}
