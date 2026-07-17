import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../models/dish_search_result.dart';
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
    return rows.map<MenuCategory>(MenuCategory.fromMap).toList(growable: false);
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
          .isFilter('deleted_at', null)
          .order('name')
          .range(offset, offset + pageSize - 1);
      all.addAll(rows.map<MenuItem>(MenuItem.fromMap));
      if (rows.length < pageSize) break;
    }
    return all;
  }

  @override
  Future<List<MenuItem>> fetchMenuItemsForRestaurant(
      String restaurantId) async {
    final rows = await supabase
        .from('menu_items')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_available', true)
        .isFilter('deleted_at', null)
        .order('name');
    return rows.map<MenuItem>(MenuItem.fromMap).toList(growable: false);
  }

  @override
  Future<List<MenuItem>> fetchMenuItemsForRestaurants(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    // inFilter builds the id list into the request — cap it so a full-
    // catalog scope (no coords: 1000+ restaurants) can't produce an
    // oversized request. The scoped list arrives popularity/distance
    // sorted, so the cap keeps the most relevant kitchens.
    final capped = ids.take(100).toList();
    final all = <MenuItem>[];
    const pageSize = 1000;
    for (var offset = 0;; offset += pageSize) {
      final rows = await supabase
          .from('menu_items')
          .select()
          .inFilter('restaurant_id', capped)
          .eq('is_available', true)
          .isFilter('deleted_at', null)
          .order('name')
          .range(offset, offset + pageSize - 1);
      all.addAll(rows.map<MenuItem>(MenuItem.fromMap));
      if (rows.length < pageSize) break;
    }
    return all;
  }

  @override
  Future<Set<String>> fetchInactiveRestaurantIds(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await supabase
        .from('restaurants')
        .select('id')
        .inFilter('id', ids.toList())
        .eq('is_active', true);
    final active = rows.map((r) => r['id'] as String).toSet();
    // Anything not confirmed active is unavailable — including ids that no
    // longer exist at all.
    return ids.difference(active);
  }

  // ── Customer search & by-id resolution ──────────────────────────────────

  @override
  Future<List<Restaurant>> searchRestaurants(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final rows = await supabase.rpc<dynamic>(
      'search_restaurants',
      params: {
        'p_query': q,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map<Restaurant>(Restaurant.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<DishSearchResult>> searchDishes(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final rows = await supabase.rpc<dynamic>(
      'search_menu_items',
      params: {
        'p_query': q,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map<DishSearchResult>(DishSearchResult.fromMap)
        .toList(growable: false);
  }

  @override
  Future<Restaurant?> fetchRestaurantById(String id) async {
    final row =
        await supabase.from('restaurants').select().eq('id', id).maybeSingle();
    return row == null ? null : Restaurant.fromMap(row);
  }

  @override
  Future<List<Restaurant>> fetchRestaurantsByIds(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await supabase
        .from('restaurants')
        .select()
        .inFilter('id', ids.toList());
    return rows.map<Restaurant>(Restaurant.fromMap).toList(growable: false);
  }

  @override
  Future<Set<String>> fetchUnavailableItemIds(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await supabase
        .from('menu_items')
        .select('id')
        .inFilter('id', ids.toList())
        .eq('is_available', true)
        .isFilter('deleted_at', null);
    final available = rows.map((r) => r['id'] as String).toSet();
    // Anything not confirmed available is unorderable — including deleted.
    return ids.difference(available);
  }

  @override
  Future<Map<String, double>> fetchItemPrices(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await supabase
        .from('menu_items')
        .select('id, price')
        .inFilter('id', ids.toList())
        .eq('is_available', true)
        .isFilter('deleted_at', null);
    return {
      for (final r in rows) r['id'] as String: (r['price'] as num).toDouble(),
    };
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
          .isFilter('deleted_at', null)
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
    String? imageUrl,
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
      if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
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
      // Persist the image (previously dropped — edits could never set a photo).
      'image_url': item.imageUrl,
      'is_veg': item.isVeg,
      'is_available': item.isAvailable,
    }).eq('id', item.id);
  }

  @override
  Future<String> uploadMenuItemImage({
    required String restaurantId,
    required Uint8List bytes,
  }) async {
    // Path keyed on restaurant + timestamp so it works before the item row
    // exists. Cache-busted URL so a re-upload shows immediately.
    final path = '$restaurantId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('menu-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
            cacheControl: '3600',
          ),
        );
    final publicUrl = supabase.storage.from('menu-images').getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
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
    // Try a hard delete for never-ordered items; fall back to a soft delete
    // when order_items references it (FK is ON DELETE RESTRICT), so order
    // history keeps the row/name while the item leaves the catalog.
    try {
      await supabase.from('menu_items').delete().eq('id', id);
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        await supabase.from('menu_items').update({
          'deleted_at': DateTime.now().toIso8601String(),
          'is_available': false,
        }).eq('id', id);
      } else {
        rethrow;
      }
    }
  }
}
