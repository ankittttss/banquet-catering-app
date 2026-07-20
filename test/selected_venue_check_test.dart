import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/data/models/banquet_venue.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/data/repositories/stub/stub_banquet_repository.dart';
import 'package:banquet_catering_app/shared/providers/banquet_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';
import 'package:banquet_catering_app/shared/providers/repositories_providers.dart';

/// Repo whose by-id lookup is fully scripted, so the reconciliation provider
/// can be pushed through every branch (active / too-small / gone / offline)
/// without a live Supabase. Mirrors the RLS behaviour under test: the
/// `fetchActiveVenueById` read only ever returns ACTIVE rows, so a
/// deactivated/deleted venue is modelled as `null`.
class _ScriptedBanquetRepo extends StubBanquetRepository {
  BanquetVenue? Function()? onFetch;
  Object? throwOnFetch;
  int fetchCalls = 0;

  @override
  Future<BanquetVenue?> fetchActiveVenueById(String id) async {
    fetchCalls++;
    if (throwOnFetch != null) throw throwOnFetch!;
    return onFetch?.call();
  }
}

BanquetVenue _venue({int? capacity, bool isActive = true}) => BanquetVenue(
      id: 'v1',
      ownerProfileId: 'op1',
      name: 'Grand Palace',
      address: 'Grand Palace, Gachibowli',
      latitude: 17.44,
      longitude: 78.35,
      capacity: capacity,
      isActive: isActive,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ScriptedBanquetRepo repo;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = _ScriptedBanquetRepo();
    container = ProviderContainer(
      overrides: [banquetRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() => container.dispose());

  EventDraftController ctrl() => container.read(eventDraftProvider.notifier);

  /// Put a banquet venue on the draft with a given guest count. Coordinates
  /// are supplied so the selection stays a valid "hall is the event location".
  void selectVenue({int guests = 50}) {
    ctrl().setVenueType(VenueType.banquetHall);
    ctrl().setGuestCount(guests);
    ctrl().setBanquetVenue(
      venueId: 'v1',
      venueName: 'Grand Palace',
      address: 'Grand Palace, Gachibowli',
      latitude: 17.44,
      longitude: 78.35,
    );
  }

  Future<VenueCheck> read() =>
      container.read(selectedBanquetVenueCheckProvider.future);

  group('selectedBanquetVenueCheckProvider', () {
    test('no banquet selection → none, repository never queried', () async {
      // Private-property flow: there is no hall to reconcile.
      ctrl().setVenueType(VenueType.privateProperty);
      final check = await read();
      expect(check.state, VenueCheckState.none);
      expect(check.isBlocking, isFalse);
      expect(repo.fetchCalls, 0);
    });

    test('banquet selected but no venue id yet → none', () async {
      ctrl().setVenueType(VenueType.banquetHall);
      final check = await read();
      expect(check.state, VenueCheckState.none);
      expect(repo.fetchCalls, 0);
    });

    test('active venue that fits → valid, carrying the fresh row', () async {
      selectVenue(guests: 50);
      repo.onFetch = () => _venue(capacity: 500);
      final check = await read();
      expect(check.state, VenueCheckState.valid);
      expect(check.isBlocking, isFalse);
      expect(check.venue?.capacity, 500);
      expect(check.venue?.address, 'Grand Palace, Gachibowli');
      expect(repo.fetchCalls, 1);
    });

    test('guest count now exceeds capacity → tooSmall (blocking)', () async {
      selectVenue(guests: 300);
      repo.onFetch = () => _venue(capacity: 200);
      final check = await read();
      expect(check.state, VenueCheckState.tooSmall);
      expect(check.isBlocking, isTrue);
    });

    test('guest count exactly equal to capacity still fits → valid', () async {
      selectVenue(guests: 200);
      repo.onFetch = () => _venue(capacity: 200);
      final check = await read();
      expect(check.state, VenueCheckState.valid);
    });

    test('venue with UNKNOWN capacity is never blocked → valid', () async {
      // Mirrors the server + tap-time gate: null capacity is never rejected.
      selectVenue(guests: 4000);
      repo.onFetch = () => _venue(capacity: null);
      final check = await read();
      expect(check.state, VenueCheckState.valid);
    });

    test('deactivated/deleted venue (active read returns null) → unavailable',
        () async {
      selectVenue(guests: 50);
      repo.onFetch = () => null;
      final check = await read();
      expect(check.state, VenueCheckState.unavailable);
      expect(check.isBlocking, isTrue);
    });

    test('network error surfaces as AsyncError — the selection is NOT cleared',
        () async {
      selectVenue(guests: 50);
      repo.throwOnFetch = Exception('offline');
      await expectLater(read(), throwsA(isA<Exception>()));
      // The draft still holds the venue; the screen shows Retry, not a reset.
      expect(container.read(eventDraftProvider).banquetVenueId, 'v1');
    });
  });
}
