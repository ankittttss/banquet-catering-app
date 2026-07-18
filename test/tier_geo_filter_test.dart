import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/data/models/restaurant.dart';
import 'package:banquet_catering_app/data/repositories/stub/stub_event_tier_repository.dart';
import 'package:banquet_catering_app/data/repositories/stub/stub_menu_repository.dart';

/// Mirrors phase42's restaurants_for_event rule (smoke-tested live against
/// the real database separately): a radius search returns ONLY restaurants
/// with real coordinates inside the radius — a restaurant with an unknown
/// location must never be treated as in-range.
void main() {
  test('radius search excludes coordinate-less and out-of-range restaurants',
      () async {
    final menuRepo = StubMenuRepository();
    menuRepo.restaurantStore.addAll(const [
      Restaurant(id: 'in', name: 'InRange', latitude: 17.44, longitude: 78.44),
      Restaurant(id: 'nocoords', name: 'Unlocated'), // no lat/lng
      Restaurant(id: 'far', name: 'Delhi', latitude: 28.61, longitude: 77.21),
    ]);
    final repo = StubEventTierRepository(menuRepo: menuRepo);

    // With a search point: only the in-radius, located restaurant survives.
    final scoped = await repo.restaurantsForTier(
      tierId: 't1',
      latitude: 17.43,
      longitude: 78.44,
    );
    final ids = scoped.map((r) => r.id).toSet();
    expect(ids, contains('in'));
    expect(ids, isNot(contains('nocoords')));
    expect(ids, isNot(contains('far')));

    // Without a search point: no geo filtering (tier-wide catalog).
    final unscoped = await repo.restaurantsForTier(tierId: 't1');
    final allIds = unscoped.map((r) => r.id).toSet();
    expect(allIds.containsAll({'in', 'nocoords', 'far'}), isTrue);
  });
}
