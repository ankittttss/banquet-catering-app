import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/data/repositories/stub/stub_banquet_repository.dart';

/// Exercises the stub `venuesNear`, which mirrors the `banquet_venues_near`
/// RPC rules: active + valid coordinates only, radius clamped to 1..100 km,
/// known-too-small capacity hidden (unknown kept), nearest-first with
/// distanceKm populated. The live RPC was smoke-tested against the real
/// database separately; this keeps the shared rules pinned in CI.
void main() {
  // Event point: central Hyderabad.
  const evLat = 17.43;
  const evLng = 78.44;

  late StubBanquetRepository repo;

  setUp(() async {
    repo = StubBanquetRepository();
    // ~0 km — at the event point itself.
    await repo.createVenue(
      ownerProfileId: 'op1',
      name: 'AtEvent',
      address: 'Central Hyderabad',
      latitude: evLat,
      longitude: evLng,
      capacity: 300,
      isActive: true,
    );
    // ~10 km north.
    await repo.createVenue(
      ownerProfileId: 'op1',
      name: 'TenKm',
      address: 'North Hyderabad',
      latitude: 17.52,
      longitude: evLng,
      capacity: null, // unknown capacity — must stay visible
      isActive: true,
    );
    // ~60 km north — outside 50, inside 100.
    await repo.createVenue(
      ownerProfileId: 'op1',
      name: 'SixtyKm',
      address: 'Far north',
      latitude: 17.97,
      longitude: evLng,
      capacity: 500,
      isActive: true,
    );
    // Delhi, ~1,270 km — never within any allowed radius.
    await repo.createVenue(
      ownerProfileId: 'op1',
      name: 'Delhi',
      address: 'Delhi',
      latitude: 28.61,
      longitude: 77.21,
      capacity: 400,
      isActive: true,
    );
    // Nearby but inactive — hidden.
    await repo.createVenue(
      ownerProfileId: 'op1',
      name: 'InactiveNear',
      address: 'Hyderabad',
      latitude: 17.44,
      longitude: evLng,
      capacity: 200,
      isActive: false,
    );
    // Nearby but no coordinates — can't be distance-matched, hidden.
    await repo.createVenue(
      ownerProfileId: 'op1',
      name: 'NoCoords',
      address: 'Hyderabad somewhere',
      capacity: 200,
      isActive: true,
    );
    // Nearby but seats only 50 — hidden when the event has more guests.
    await repo.createVenue(
      ownerProfileId: 'op1',
      name: 'TooSmall',
      address: 'Hyderabad',
      latitude: 17.42,
      longitude: evLng,
      capacity: 50,
      isActive: true,
    );
  });

  test('50 km: nearest-first, in-radius only, distances populated', () async {
    final rows = await repo.venuesNear(latitude: evLat, longitude: evLng);
    expect(rows.map((v) => v.name), ['AtEvent', 'TooSmall', 'TenKm']);
    // SixtyKm (out of radius), Delhi, InactiveNear, NoCoords all absent.
    expect(rows.first.distanceKm, lessThan(1));
    for (var i = 1; i < rows.length; i++) {
      expect(
          rows[i].distanceKm!, greaterThanOrEqualTo(rows[i - 1].distanceKm!));
      expect(rows[i].distanceKm!, lessThanOrEqualTo(50));
    }
  });

  test('expanding to 100 km pulls in the 60 km venue but never Delhi',
      () async {
    final rows = await repo.venuesNear(
      latitude: evLat,
      longitude: evLng,
      radiusKm: 100,
    );
    expect(rows.map((v) => v.name).toList(),
        ['AtEvent', 'TooSmall', 'TenKm', 'SixtyKm']);
  });

  test('radius is clamped: 5000 km behaves as 100 km (no Delhi)', () async {
    final rows = await repo.venuesNear(
      latitude: evLat,
      longitude: evLng,
      radiusKm: 5000,
    );
    expect(rows.map((v) => v.name), isNot(contains('Delhi')));
    expect(rows.map((v) => v.name), contains('SixtyKm'));
  });

  test('capacity: known-too-small hidden, unknown capacity kept', () async {
    final rows = await repo.venuesNear(
      latitude: evLat,
      longitude: evLng,
      minCapacity: 100,
    );
    expect(rows.map((v) => v.name), isNot(contains('TooSmall')));
    expect(rows.map((v) => v.name), contains('TenKm')); // capacity unknown
    expect(rows.map((v) => v.name), contains('AtEvent')); // 300 >= 100
  });
}
