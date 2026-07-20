import 'dart:typed_data';

import '../models/menu_item.dart';
import '../models/restaurant.dart';

/// One page of the admin restaurants list. The catalog holds 1000+ rows, so
/// the list is always fetched server-side paginated — never in full.
class AdminRestaurantPage {
  const AdminRestaurantPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<Restaurant> items;

  /// Total rows matching the current search/status filter (across all pages).
  final int total;
  final int page;
  final int pageSize;

  int get pageCount => total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
  bool get hasPrev => page > 0;
  bool get hasNext => page < pageCount - 1;
}

/// Admin-side catalog management: onboarding, editing, lifecycle and images
/// for restaurants. Requires the signed-in user to be an admin at the
/// database level (`restaurants_admin_write` RLS + phase34 storage policies).
///
/// Reads here intentionally do NOT filter on status/is_active — the admin
/// sees drafts, suspended and archived rows; customers never hit this repo.
abstract interface class AdminRestaurantRepository {
  /// Server-side paginated list, newest edits first. [search] matches the
  /// restaurant name (case-insensitive); [status] narrows to one lifecycle
  /// state; null means all states.
  Future<AdminRestaurantPage> fetchPage({
    String? search,
    RestaurantStatus? status,
    int page = 0,
    int pageSize = 20,
  });

  Future<Restaurant?> fetchById(String id);

  /// Step 1 of onboarding — creates the row immediately as a hidden draft so
  /// wizard progress is never lost. Only basics are needed at this point.
  Future<Restaurant> createDraft({
    required String name,
    String? cuisinesDisplay,
    bool isPureVeg = false,
    String? tag,
  });

  /// Partial update of a restaurant's editable details. Only non-null
  /// arguments are written. Exception: [tag] passed as an empty string
  /// clears the tag (null keeps it, matching copyWith semantics).
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
  });

  /// Lifecycle transition. Publishing an incomplete restaurant is rejected
  /// by the database (phase34 publish gate) — implementations surface that
  /// error message so the UI can show it verbatim.
  Future<Restaurant> setStatus(String id, RestaurantStatus status);

  /// Uploads the square card logo to the `restaurant-logos` bucket and
  /// writes the (cache-busted) public URL to the row. Returns the URL.
  Future<String> uploadLogo({
    required String restaurantId,
    required Uint8List bytes,
  });

  /// Same as [uploadLogo] for the wide detail-page cover image.
  Future<String> uploadCover({
    required String restaurantId,
    required Uint8List bytes,
  });

  /// Every menu item of one restaurant, including unavailable ones — powers
  /// the scoped admin menu manager and the publish checklist.
  Future<List<MenuItem>> fetchAllItemsForRestaurant(String restaurantId);
}
