import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../models/menu_item.dart';
import '../../models/restaurant.dart';
import '../admin_restaurant_repository.dart';

class SupabaseAdminRestaurantRepository implements AdminRestaurantRepository {
  static const _logoBucket = 'restaurant-logos';

  @override
  Future<AdminRestaurantPage> fetchPage({
    String? search,
    RestaurantStatus? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    var query = supabase.from('restaurants').select();
    if (status != null) query = query.eq('status', status.dbValue);
    final term = search?.trim() ?? '';
    if (term.isNotEmpty) query = query.ilike('name', '%$term%');

    final from = page * pageSize;
    final res = await query
        .order('updated_at', ascending: false)
        .order('name')
        .range(from, from + pageSize - 1)
        .count(CountOption.exact);

    return AdminRestaurantPage(
      items: res.data.map<Restaurant>(Restaurant.fromMap).toList(),
      total: res.count,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Restaurant?> fetchById(String id) async {
    final row =
        await supabase.from('restaurants').select().eq('id', id).maybeSingle();
    return row == null ? null : Restaurant.fromMap(row);
  }

  @override
  Future<Restaurant> createDraft({
    required String name,
    String? cuisinesDisplay,
    bool isPureVeg = false,
    String? tag,
  }) async {
    final row = await supabase
        .from('restaurants')
        .insert({
          'name': name.trim(),
          'status': RestaurantStatus.draft.dbValue,
          if (cuisinesDisplay != null && cuisinesDisplay.trim().isNotEmpty)
            'cuisines_display': cuisinesDisplay.trim(),
          'is_pure_veg': isPureVeg,
          if (tag != null && tag.trim().isNotEmpty) 'tag': tag.trim(),
        })
        .select()
        .single();
    return Restaurant.fromMap(row);
  }

  @override
  Future<Restaurant> update(
    String id, {
    String? name,
    String? cuisinesDisplay,
    bool? isPureVeg,
    String? tag,
    String? address,
    double? latitude,
    double? longitude,
    double? pricePerPlate,
    double? perGuestPriceMin,
    double? perGuestPriceMax,
    int? minGuests,
    double? deliveryCharge,
    int? deliveryMinMinutes,
    int? deliveryMaxMinutes,
    String? heroBgHex,
    String? heroEmoji,
  }) async {
    final patch = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (cuisinesDisplay != null) 'cuisines_display': cuisinesDisplay.trim(),
      if (isPureVeg != null) 'is_pure_veg': isPureVeg,
      // Empty string = clear the tag (see interface contract).
      if (tag != null) 'tag': tag.trim().isEmpty ? null : tag.trim(),
      if (address != null) 'address': address.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (pricePerPlate != null) 'price_per_plate': pricePerPlate,
      if (perGuestPriceMin != null) 'per_guest_price_min': perGuestPriceMin,
      if (perGuestPriceMax != null) 'per_guest_price_max': perGuestPriceMax,
      if (minGuests != null) 'min_guests': minGuests,
      if (deliveryCharge != null) 'delivery_charge': deliveryCharge,
      if (deliveryMinMinutes != null)
        'delivery_min_minutes': deliveryMinMinutes,
      if (deliveryMaxMinutes != null)
        'delivery_max_minutes': deliveryMaxMinutes,
      if (heroBgHex != null) 'hero_bg_hex': heroBgHex,
      if (heroEmoji != null) 'hero_emoji': heroEmoji,
    };
    final row = await supabase
        .from('restaurants')
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return Restaurant.fromMap(row);
  }

  @override
  Future<Restaurant> setStatus(String id, RestaurantStatus status) async {
    // A publish attempt on an incomplete restaurant raises in the DB
    // (phase34 gate). The PostgrestException.message carries the exact
    // human-readable reason — callers show it as-is.
    final row = await supabase
        .from('restaurants')
        .update({'status': status.dbValue})
        .eq('id', id)
        .select()
        .single();
    return Restaurant.fromMap(row);
  }

  @override
  Future<String> uploadLogo({
    required String restaurantId,
    required Uint8List bytes,
  }) =>
      _uploadImage(
        restaurantId: restaurantId,
        bytes: bytes,
        fileName: 'logo.jpg',
        column: 'logo_url',
      );

  @override
  Future<String> uploadCover({
    required String restaurantId,
    required Uint8List bytes,
  }) =>
      _uploadImage(
        restaurantId: restaurantId,
        bytes: bytes,
        fileName: 'cover.jpg',
        column: 'cover_image_url',
      );

  /// Avatar-upload pattern (see SupabaseProfileRepository): upsert in place,
  /// then store a cache-busted public URL so a re-upload shows immediately.
  Future<String> _uploadImage({
    required String restaurantId,
    required Uint8List bytes,
    required String fileName,
    required String column,
  }) async {
    final path = '$restaurantId/$fileName';
    await supabase.storage.from(_logoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
            cacheControl: '3600',
          ),
        );
    final publicUrl = supabase.storage.from(_logoBucket).getPublicUrl(path);
    final busted = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    await supabase
        .from('restaurants')
        .update({column: busted}).eq('id', restaurantId);
    return busted;
  }

  @override
  Future<List<MenuItem>> fetchAllItemsForRestaurant(
    String restaurantId,
  ) async {
    // One restaurant's menu is well under the 1000-row PostgREST cap
    // (catalog average ~21 items), so no pagination needed here.
    final rows = await supabase
        .from('menu_items')
        .select()
        .eq('restaurant_id', restaurantId)
        .isFilter('deleted_at', null)
        .order('name');
    return rows.map<MenuItem>(MenuItem.fromMap).toList(growable: false);
  }
}
