import '../../../core/utils/geo.dart';
import '../../models/event_tier.dart';
import '../../models/restaurant.dart';
import '../event_tier_repository.dart';
import 'stub_menu_repository.dart';

class StubEventTierRepository implements EventTierRepository {
  StubEventTierRepository({StubMenuRepository? menuRepo})
      : _menuRepo = menuRepo ?? StubMenuRepository();

  final StubMenuRepository _menuRepo;

  @override
  Future<List<EventTier>> fetchTiers() async => List.of(fallbackEventTiers);

  @override
  Future<List<Restaurant>> restaurantsForTier({
    required String tierId,
    double? latitude,
    double? longitude,
    double radiusKm = kServiceRadiusKm,
  }) async {
    // Stub mode doesn't model per-guest price bands — every active
    // restaurant qualifies. The GEO rule, however, mirrors phase42's
    // restaurants_for_event exactly: a radius search only returns
    // restaurants with real coordinates inside the radius — unknown
    // locations never masquerade as in-range.
    final all = await _menuRepo.fetchRestaurants();
    if (latitude == null || longitude == null) return all;
    return all.where((r) {
      final d = haversineKm(
        lat1: latitude,
        lng1: longitude,
        lat2: r.latitude,
        lng2: r.longitude,
      );
      return d != null && d <= radiusKm;
    }).toList(growable: false);
  }
}
