import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/data/models/banquet_venue.dart';
import 'package:banquet_catering_app/data/repositories/stub/stub_banquet_repository.dart';
import 'package:banquet_catering_app/shared/providers/banquet_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';
import 'package:banquet_catering_app/shared/providers/repositories_providers.dart';

/// Records every venuesNear call so tests can assert exactly when the
/// repository is hit and with which arguments.
class _RecordingBanquetRepo extends StubBanquetRepository {
  final calls = <({double lat, double lng, double radiusKm, int? minCap})>[];

  @override
  Future<List<BanquetVenue>> venuesNear({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int? minCapacity,
  }) {
    calls.add((
      lat: latitude,
      lng: longitude,
      radiusKm: radiusKm,
      minCap: minCapacity,
    ));
    return super.venuesNear(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      minCapacity: minCapacity,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingBanquetRepo repo;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = _RecordingBanquetRepo();
    container = ProviderContainer(
      overrides: [banquetRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() => container.dispose());

  group('nearbyVenuesProvider', () {
    test(
        'no event coordinates → empty result, repository NEVER queried '
        '(and the home address is never involved — the provider only reads '
        'the event draft)', () async {
      // Planning with an address but no pinned point — the exact state the
      // picker shows its confirm-location message for.
      container
          .read(eventDraftProvider.notifier)
          .setEventLocation(address: 'Community Hall, somewhere');

      final rows = await container.read(nearbyVenuesProvider.future);
      expect(rows, isEmpty);
      expect(repo.calls, isEmpty); // never called → nothing to sort around
    });

    test('default radius is 50 km and the event coords are passed', () async {
      container.read(eventDraftProvider.notifier).setEventLocation(
            address: 'Grand Palace, Gachibowli',
            latitude: 17.44,
            longitude: 78.35,
          );

      await container.read(nearbyVenuesProvider.future);
      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.radiusKm, 50);
      expect(repo.calls.single.lat, 17.44);
      expect(repo.calls.single.lng, 78.35);
      // Guest count travels along for the capacity filter (default 50).
      expect(repo.calls.single.minCap, 50);
    });

    test('expanding the radius to 100 triggers a NEW repository query',
        () async {
      container.read(eventDraftProvider.notifier).setEventLocation(
            address: 'Grand Palace',
            latitude: 17.44,
            longitude: 78.35,
          );
      // Keep the provider alive across the radius change, like the open
      // picker sheet does.
      final sub = container.listen(nearbyVenuesProvider, (_, __) {});

      await container.read(nearbyVenuesProvider.future);
      expect(repo.calls, hasLength(1));

      container.read(venueSearchRadiusProvider.notifier).state = 100;
      await container.read(nearbyVenuesProvider.future);

      expect(repo.calls, hasLength(2));
      expect(repo.calls.last.radiusKm, 100);
      sub.close();
    });
  });

  group('venueSearchRadiusProvider', () {
    test('defaults to 50', () {
      final sub = container.listen(venueSearchRadiusProvider, (_, __) {});
      expect(container.read(venueSearchRadiusProvider), 50);
      sub.close();
    });

    test('resets to 50 after the last listener goes away (picker closed)',
        () async {
      var sub = container.listen(venueSearchRadiusProvider, (_, __) {});
      container.read(venueSearchRadiusProvider.notifier).state = 100;
      expect(container.read(venueSearchRadiusProvider), 100);

      // Close the sheet → last listener gone → autoDispose tears it down.
      sub.close();
      await container.pump();

      // Re-open: a fresh state, back at the 50 km default.
      sub = container.listen(venueSearchRadiusProvider, (_, __) {});
      expect(container.read(venueSearchRadiusProvider), 50);
      sub.close();
    });
  });
}
