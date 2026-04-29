import '../../models/event_tier.dart';
import '../../models/restaurant.dart';
import '../event_tier_repository.dart';
import 'stub_menu_repository.dart';

class StubEventTierRepository implements EventTierRepository {
  StubEventTierRepository({StubMenuRepository? menuRepo})
      : _menuRepo = menuRepo ?? StubMenuRepository();

  final StubMenuRepository _menuRepo;

  @override
  Future<List<EventTier>> fetchTiers() async =>
      List.of(fallbackEventTiers);

  @override
  Future<List<Restaurant>> restaurantsForTier({
    required String tierId,
    double? latitude,
    double? longitude,
    double radiusKm = 25,
  }) async {
    // Stub mode doesn't model per-guest price bands — just return every
    // active restaurant so UI dev keeps rolling.
    return _menuRepo.fetchRestaurants();
  }
}
