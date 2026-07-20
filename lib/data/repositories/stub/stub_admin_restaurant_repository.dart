import 'dart:typed_data';

import '../../models/menu_item.dart';
import '../../models/restaurant.dart';
import '../admin_restaurant_repository.dart';
import 'stub_menu_repository.dart';

/// In-memory admin catalog for UI dev without Supabase. Shares the
/// [StubMenuRepository] stores so onboarded restaurants appear in the
/// customer stub flows within the same session.
class StubAdminRestaurantRepository implements AdminRestaurantRepository {
  StubAdminRestaurantRepository(this._menu);

  final StubMenuRepository _menu;
  var _idSeq = 100;

  List<Restaurant> get _restaurants => _menu.restaurantStore;

  @override
  Future<AdminRestaurantPage> fetchPage({
    String? search,
    RestaurantStatus? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    final term = (search ?? '').trim().toLowerCase();
    final filtered = _restaurants
        .where((r) => status == null || r.status == status)
        .where((r) => term.isEmpty || r.name.toLowerCase().contains(term))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final from = page * pageSize;
    return AdminRestaurantPage(
      items: from >= filtered.length
          ? const []
          : filtered.sublist(
              from,
              (from + pageSize).clamp(0, filtered.length),
            ),
      total: filtered.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Restaurant?> fetchById(String id) async {
    for (final r in _restaurants) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<Restaurant> createDraft({
    required String name,
    String? cuisinesDisplay,
    bool isPureVeg = false,
    String? tag,
  }) async {
    final draft = Restaurant(
      id: 'r${++_idSeq}',
      name: name.trim(),
      cuisinesDisplay: cuisinesDisplay?.trim(),
      isPureVeg: isPureVeg,
      tag: (tag == null || tag.trim().isEmpty) ? null : tag.trim(),
      status: RestaurantStatus.draft,
      isActive: false,
      updatedAt: DateTime.now(),
    );
    _restaurants.add(draft);
    return draft;
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
    final i = _indexOf(id);
    // perGuestPriceMin/Max aren't on the model (RPC-only fields) — ignored
    // here, written straight to the row by the Supabase impl.
    var next = _restaurants[i].copyWith(
      name: name,
      cuisinesDisplay: cuisinesDisplay,
      isPureVeg: isPureVeg,
      tag: tag,
      address: address,
      latitude: latitude,
      longitude: longitude,
      pricePerPlate: pricePerPlate,
      minGuests: minGuests,
      deliveryCharge: deliveryCharge,
      deliveryMinMinutes: deliveryMinMinutes,
      deliveryMaxMinutes: deliveryMaxMinutes,
      heroBgHex: heroBgHex,
      heroEmoji: heroEmoji,
      updatedAt: DateTime.now(),
    );
    if (tag != null && tag.trim().isEmpty) {
      // copyWith can't null a field — rebuild for the "clear tag" contract.
      next = Restaurant(
        id: next.id,
        name: next.name,
        logoUrl: next.logoUrl,
        deliveryCharge: next.deliveryCharge,
        isActive: next.isActive,
        pricePerPlate: next.pricePerPlate,
        minGuests: next.minGuests,
        deliveryMinMinutes: next.deliveryMinMinutes,
        deliveryMaxMinutes: next.deliveryMaxMinutes,
        rating: next.rating,
        ratingsCount: next.ratingsCount,
        cuisinesDisplay: next.cuisinesDisplay,
        heroBgHex: next.heroBgHex,
        heroEmoji: next.heroEmoji,
        tag: null,
        isPureVeg: next.isPureVeg,
        popularityScore: next.popularityScore,
        latitude: next.latitude,
        longitude: next.longitude,
        address: next.address,
        status: next.status,
        coverImageUrl: next.coverImageUrl,
        publishedAt: next.publishedAt,
        updatedAt: next.updatedAt,
      );
    }
    _restaurants[i] = next;
    return next;
  }

  @override
  Future<Restaurant> setStatus(String id, RestaurantStatus status) async {
    final i = _indexOf(id);
    final r = _restaurants[i];

    // Mirror the phase34 DB publish gate so dev mode fails identically.
    if (status == RestaurantStatus.published &&
        r.status != RestaurantStatus.published) {
      _validatePublish(r);
    }

    final now = DateTime.now();
    final next = r.copyWith(
      status: status,
      isActive: status == RestaurantStatus.published,
      publishedAt: status == RestaurantStatus.published ? now : r.publishedAt,
      archivedAt: status == RestaurantStatus.archived ? now : r.archivedAt,
      updatedAt: now,
    );
    _restaurants[i] = next;
    return next;
  }

  void _validatePublish(Restaurant r) {
    if (r.name.trim().isEmpty) {
      throw StateError('Cannot publish: restaurant name is required.');
    }
    if (r.pricePerPlate == null || r.pricePerPlate! <= 0) {
      throw StateError(
        'Cannot publish "${r.name}": price per plate is required.',
      );
    }
    if (r.minGuests == null || r.minGuests! <= 0) {
      throw StateError(
        'Cannot publish "${r.name}": minimum guests is required.',
      );
    }
    if ((r.address ?? '').trim().isEmpty ||
        r.latitude == null ||
        r.longitude == null) {
      throw StateError(
        'Cannot publish "${r.name}": address and map location are required.',
      );
    }
    if (r.logoUrl == null && r.coverImageUrl == null) {
      throw StateError(
        'Cannot publish "${r.name}": a logo or cover image is required.',
      );
    }
    final hasItem =
        _menu.itemStore.any((it) => it.restaurantId == r.id && it.isAvailable);
    if (!hasItem) {
      throw StateError(
        'Cannot publish "${r.name}": add at least one available menu item first.',
      );
    }
  }

  @override
  Future<String> uploadLogo({
    required String restaurantId,
    required Uint8List bytes,
  }) async {
    // Offline mode can't host bytes — pretend with a placeholder so the
    // publish gate and card preview still work.
    const url =
        'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80&auto=format&fit=crop';
    final i = _indexOf(restaurantId);
    _restaurants[i] = _restaurants[i].copyWith(
      logoUrl: url,
      updatedAt: DateTime.now(),
    );
    return url;
  }

  @override
  Future<String> uploadCover({
    required String restaurantId,
    required Uint8List bytes,
  }) async {
    const url =
        'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=1200&q=80&auto=format&fit=crop';
    final i = _indexOf(restaurantId);
    _restaurants[i] = _restaurants[i].copyWith(
      coverImageUrl: url,
      updatedAt: DateTime.now(),
    );
    return url;
  }

  @override
  Future<List<MenuItem>> fetchAllItemsForRestaurant(
    String restaurantId,
  ) async =>
      _menu.itemStore
          .where((it) => it.restaurantId == restaurantId)
          .toList(growable: false);

  int _indexOf(String id) {
    final i = _restaurants.indexWhere((r) => r.id == id);
    if (i == -1) throw StateError('Restaurant not found: $id');
    return i;
  }
}
