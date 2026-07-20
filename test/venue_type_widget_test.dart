import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/banquet_venue.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/data/repositories/stub/stub_banquet_repository.dart';
import 'package:banquet_catering_app/features/user/screens/venue_type_screen.dart';
import 'package:banquet_catering_app/shared/providers/banquet_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';
import 'package:banquet_catering_app/shared/providers/repositories_providers.dart';

/// Repo with scripted, call-counting behaviour so behavioural tests can drive
/// the REAL nearbyVenuesProvider / selectedBanquetVenueCheckProvider through
/// fail-then-recover and radius-dependent results — i.e. Retry/Expand/Change
/// exercise real provider logic rather than a hand-set AsyncValue.
class _ScriptedRepo extends StubBanquetRepository {
  List<BanquetVenue> Function(double radiusKm)? nearbyFn;
  int nearbyFailFirst = 0;
  int nearbyCalls = 0;

  final Map<String, BanquetVenue> byId = {};
  int byIdFailFirst = 0;
  int byIdCalls = 0;

  @override
  Future<List<BanquetVenue>> venuesNear({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int? minCapacity,
  }) async {
    nearbyCalls++;
    if (nearbyCalls <= nearbyFailFirst) throw Exception('nearby down');
    return nearbyFn?.call(radiusKm) ?? const [];
  }

  @override
  Future<BanquetVenue?> fetchActiveVenueById(String id) async {
    byIdCalls++;
    if (byIdCalls <= byIdFailFirst) throw Exception('byId down');
    return byId[id];
  }
}

/// Widget tests for the venue-type screen: the event-details prerequisite
/// guard, the live selected-venue reconciliation card (valid / too-small /
/// unavailable / loading / error) and its effect on the Continue gate, plus
/// picker + navigation flows. Everything runs on provider overrides — no
/// network, no Supabase.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uuidTier = '00000000-0000-4000-8000-000000000111';

  BanquetVenue venue({int? capacity = 500}) => BanquetVenue(
        id: 'v1',
        ownerProfileId: 'op1',
        name: 'Grand Palace',
        address: 'Grand Palace, Gachibowli',
        latitude: 17.44,
        longitude: 78.35,
        capacity: capacity,
      );

  late ProviderContainer container;

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    // Tall surface so the lazy ListView builds the summary card too.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.eventVenueType,
      routes: [
        GoRoute(
          path: AppRoutes.eventVenueType,
          builder: (_, __) => const VenueTypeScreen(),
        ),
        GoRoute(
          path: AppRoutes.eventDetails,
          builder: (_, __) => const Scaffold(body: Text('DETAILS-SCREEN')),
        ),
        GoRoute(
          path: AppRoutes.eventProperty,
          builder: (_, __) => const Scaffold(body: Text('PROPERTY-SCREEN')),
        ),
        GoRoute(
          path: AppRoutes.userHome,
          builder: (_, __) => const Scaffold(body: Text('HOME-SCREEN')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  /// Rebuild after seeding the draft, then let the async reconciliation
  /// FutureProvider resolve from loading → data.
  Future<void> applySeed(WidgetTester tester) async {
    await tester.pump(); // provider is now watched → starts loading
    await tester.pump(const Duration(milliseconds: 100)); // future resolves
  }

  /// Flush the draft controller's 250 ms persist-debounce Timer so it doesn't
  /// outlive the widget tree (tests that navigate settle it via pumpAndSettle).
  Future<void> flushPersist(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  /// Fill every event-details field with a schedule valid on the real clock
  /// (a far-future date keeps planningNextStep deterministic in practice), so
  /// the screen's prerequisite guard is satisfied and the venue step renders.
  void seedDetails(ProviderContainer c) {
    final ctrl = c.read(eventDraftProvider.notifier);
    final d = DateTime.now().add(const Duration(days: 30));
    ctrl.setEventName('Widget Test Event');
    ctrl.setSession('Dinner');
    ctrl.setDate(DateTime(d.year, d.month, d.day));
    ctrl.setStartTime(DateTime(d.year, d.month, d.day, 19));
    ctrl.setEventLocation(
      address: 'Grand Palace, Gachibowli',
      latitude: 17.44,
      longitude: 78.35,
    );
    ctrl.setTier(tierId: uuidTier, tierCode: 'STANDARD');
  }

  /// Details + a banquet-hall selection with a concrete venue on the draft.
  /// Coordinates are passed so the hall-is-the-event-location pin survives.
  void seedBanquetWithVenue(ProviderContainer c, {int guests = 50}) {
    seedDetails(c);
    final ctrl = c.read(eventDraftProvider.notifier);
    ctrl.setGuestCount(guests);
    ctrl.setVenueType(VenueType.banquetHall);
    ctrl.setBanquetVenue(
      venueId: 'v1',
      venueName: 'Grand Palace',
      address: 'Grand Palace, Gachibowli',
      latitude: 17.44,
      longitude: 78.35,
    );
  }

  Finder continueBtn() => find.widgetWithText(FilledButton, 'Continue');
  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(continueBtn()).onPressed != null;

  // Override the reconciliation provider to a fixed AsyncValue.
  Override checkData(VenueCheck value) =>
      selectedBanquetVenueCheckProvider.overrideWith((ref) async => value);
  Override checkLoading() => selectedBanquetVenueCheckProvider
      .overrideWith((ref) => Completer<VenueCheck>().future);
  Override checkError() => selectedBanquetVenueCheckProvider
      .overrideWith((ref) async => throw Exception('offline'));

  group('event-details prerequisite guard', () {
    testWidgets('incomplete details → guard view, no Continue, routes back',
        (tester) async {
      await pumpScreen(tester);
      // Nothing seeded → planningNextStep points at Event Details.
      await tester.pump();

      expect(find.text('Finish your event details first'), findsOneWidget);
      expect(find.text('Go to event details'), findsOneWidget);
      expect(continueBtn(), findsNothing); // no venue footer in this state

      await tester.tap(find.text('Go to event details'));
      await tester.pumpAndSettle();
      expect(find.text('DETAILS-SCREEN'), findsOneWidget);
    });

    testWidgets('complete details → the venue step renders', (tester) async {
      await pumpScreen(tester);
      seedDetails(container);
      await applySeed(tester);

      expect(find.text('Finish your event details first'), findsNothing);
      expect(find.text('Hall or your place?'), findsOneWidget);
      // Nothing picked yet → Continue disabled.
      expect(continueEnabled(tester), isFalse);
      await flushPersist(tester);
    });
  });

  group('selected banquet venue reconciliation card', () {
    testWidgets('valid → summary card shown, Continue enabled, goes to browse',
        (tester) async {
      await pumpScreen(
        tester,
        overrides: [
          checkData(VenueCheck(VenueCheckState.valid, venue: venue())),
        ],
      );
      seedBanquetWithVenue(container);
      await applySeed(tester);

      expect(find.text('Selected venue'), findsOneWidget);
      expect(find.text('Grand Palace'), findsWidgets);
      expect(find.text('Up to 500 guests'), findsOneWidget);
      expect(find.text('Change venue'), findsOneWidget);
      expect(continueEnabled(tester), isTrue);

      await tester.tap(continueBtn());
      await tester.pumpAndSettle();
      expect(find.text('HOME-SCREEN'), findsOneWidget);
    });

    testWidgets('guest count beyond capacity → blocking card, Continue off',
        (tester) async {
      await pumpScreen(
        tester,
        overrides: [
          checkData(
            VenueCheck(VenueCheckState.tooSmall, venue: venue(capacity: 200)),
          ),
        ],
      );
      seedBanquetWithVenue(container, guests: 300);
      await applySeed(tester);

      expect(find.textContaining('no longer fits your guests'), findsOneWidget);
      expect(find.text('Pick a bigger venue'), findsOneWidget);
      expect(continueEnabled(tester), isFalse);
      await flushPersist(tester);
    });

    testWidgets('deactivated/deleted venue → unavailable card, Continue off',
        (tester) async {
      await pumpScreen(
        tester,
        overrides: [checkData(const VenueCheck(VenueCheckState.unavailable))],
      );
      seedBanquetWithVenue(container);
      await applySeed(tester);

      expect(find.textContaining('no longer available'), findsOneWidget);
      expect(find.text('Choose another venue'), findsOneWidget);
      expect(continueEnabled(tester), isFalse);
      await flushPersist(tester);
    });

    testWidgets('validation loading → checking state, Continue off',
        (tester) async {
      await pumpScreen(tester, overrides: [checkLoading()]);
      seedBanquetWithVenue(container);
      await applySeed(tester);

      expect(find.textContaining('Checking your venue'), findsOneWidget);
      expect(continueEnabled(tester), isFalse);
      await flushPersist(tester);
    });

    testWidgets('validation error → Retry offered, Continue stays off',
        (tester) async {
      await pumpScreen(tester, overrides: [checkError()]);
      seedBanquetWithVenue(container);
      await applySeed(tester);

      expect(find.textContaining("Couldn't verify this venue"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(continueEnabled(tester), isFalse);
      await flushPersist(tester);
    });

    testWidgets('Change venue reopens the picker', (tester) async {
      await pumpScreen(
        tester,
        overrides: [
          checkData(VenueCheck(VenueCheckState.valid, venue: venue())),
          // Picker reads this; empty keeps it on a settled message state.
          nearbyVenuesProvider
              .overrideWith((ref) async => const <BanquetVenue>[]),
        ],
      );
      seedBanquetWithVenue(container);
      await applySeed(tester);

      await tester.tap(find.text('Change venue'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a banquet venue'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('private property → Continue routes to the property screen',
        (tester) async {
      await pumpScreen(tester);
      seedDetails(container);
      container
          .read(eventDraftProvider.notifier)
          .setVenueType(VenueType.privateProperty);
      await applySeed(tester);

      expect(continueEnabled(tester), isTrue);
      await tester.tap(continueBtn());
      await tester.pumpAndSettle();
      expect(find.text('PROPERTY-SCREEN'), findsOneWidget);
    });

    testWidgets('banquet with no venue yet → Continue opens the picker',
        (tester) async {
      await pumpScreen(
        tester,
        overrides: [
          nearbyVenuesProvider
              .overrideWith((ref) async => const <BanquetVenue>[]),
        ],
      );
      seedDetails(container);
      container
          .read(eventDraftProvider.notifier)
          .setVenueType(VenueType.banquetHall);
      await applySeed(tester);

      // No venue on the draft → no summary card, but Continue is enabled and
      // opens the picker rather than navigating.
      expect(find.text('Selected venue'), findsNothing);
      expect(continueEnabled(tester), isTrue);

      await tester.tap(continueBtn());
      await tester.pumpAndSettle();
      expect(find.text('Pick a banquet venue'), findsOneWidget);
    });
  });

  group('picker states', () {
    testWidgets('empty within 50 km → offers to expand to 100 km',
        (tester) async {
      await pumpScreen(
        tester,
        overrides: [
          nearbyVenuesProvider
              .overrideWith((ref) async => const <BanquetVenue>[]),
        ],
      );
      seedDetails(container);
      container
          .read(eventDraftProvider.notifier)
          .setVenueType(VenueType.banquetHall);
      await applySeed(tester);

      await tester.tap(continueBtn());
      await tester.pumpAndSettle();
      expect(find.textContaining('No venues near your event'), findsOneWidget);
      expect(find.text('Expand search to 100 km'), findsOneWidget);
    });

    testWidgets('picker fetch error → load error + Retry', (tester) async {
      await pumpScreen(
        tester,
        overrides: [
          nearbyVenuesProvider
              .overrideWith((ref) async => throw Exception('down')),
        ],
      );
      seedDetails(container);
      container
          .read(eventDraftProvider.notifier)
          .setVenueType(VenueType.banquetHall);
      await applySeed(tester);

      await tester.tap(continueBtn());
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't load venues"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  // These drive the REAL providers through a scripted repo, so the taps
  // actually re-run provider logic (fail→recover, radius-dependent results),
  // not a pre-set AsyncValue.
  group('behavioural (real providers + scripted repo)', () {
    BanquetVenue vRow({
      required String id,
      required String name,
      int? capacity,
      double? distance,
    }) =>
        BanquetVenue(
          id: id,
          ownerProfileId: 'op',
          name: name,
          address: '$name address',
          latitude: 17.44,
          longitude: 78.35,
          capacity: capacity,
          distanceKm: distance,
        );

    testWidgets('selected-venue Retry re-fetches and recovers to a valid card',
        (tester) async {
      final repo = _ScriptedRepo()
        ..byIdFailFirst = 1 // first verify throws, second succeeds
        ..byId['v1'] = vRow(id: 'v1', name: 'Grand Palace', capacity: 500);
      await pumpScreen(
        tester,
        overrides: [banquetRepositoryProvider.overrideWithValue(repo)],
      );
      seedBanquetWithVenue(container); // v1 on the draft
      await applySeed(tester);

      // First live check threw → error card, Continue blocked.
      expect(find.textContaining("Couldn't verify this venue"), findsOneWidget);
      expect(continueEnabled(tester), isFalse);

      await tester.tap(find.text('Retry'));
      await tester.pump(); // invalidate → re-fetch begins
      await tester.pump(const Duration(milliseconds: 100)); // resolves
      expect(find.text('Selected venue'), findsOneWidget);
      expect(continueEnabled(tester), isTrue);
      expect(repo.byIdCalls, 2);
      await flushPersist(tester);
    });

    testWidgets('picker Retry re-queries and shows the venue list',
        (tester) async {
      final repo = _ScriptedRepo()
        ..nearbyFailFirst = 1
        ..nearbyFn = (_) =>
            [vRow(id: 'v1', name: 'Grand Palace', capacity: 500, distance: 2)];
      await pumpScreen(
        tester,
        overrides: [banquetRepositoryProvider.overrideWithValue(repo)],
      );
      seedDetails(container);
      container
          .read(eventDraftProvider.notifier)
          .setVenueType(VenueType.banquetHall);
      await applySeed(tester);

      await tester.tap(continueBtn()); // open picker
      await tester.pumpAndSettle(); // first query threw → error state
      expect(find.textContaining("Couldn't load venues"), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle(); // re-query → list
      expect(find.text('Grand Palace'), findsOneWidget);
      expect(repo.nearbyCalls, 2);
    });

    testWidgets('Expand to 100 km changes the radius and reloads results',
        (tester) async {
      final repo = _ScriptedRepo()
        // Nothing within 50 km; a hall appears once the radius widens.
        ..nearbyFn = (r) => r >= 100
            ? [vRow(id: 'v1', name: 'Far Palace', capacity: 500, distance: 70)]
            : const <BanquetVenue>[];
      await pumpScreen(
        tester,
        overrides: [banquetRepositoryProvider.overrideWithValue(repo)],
      );
      seedDetails(container);
      container
          .read(eventDraftProvider.notifier)
          .setVenueType(VenueType.banquetHall);
      await applySeed(tester);

      await tester.tap(continueBtn());
      await tester.pumpAndSettle(); // radius 50 → empty
      expect(find.text('Expand search to 100 km'), findsOneWidget);

      await tester.tap(find.text('Expand search to 100 km'));
      await tester.pumpAndSettle(); // radius → 100 → re-query → list
      expect(find.text('Far Palace'), findsOneWidget);
      expect(find.textContaining('No venues near your event'), findsNothing);
    });

    testWidgets('Change venue → picking a different hall updates draft + card',
        (tester) async {
      final vA = vRow(id: 'vA', name: 'Palace A', capacity: 500, distance: 2);
      final vB = vRow(id: 'vB', name: 'Palace B', capacity: 800, distance: 3);
      final repo = _ScriptedRepo();
      repo.nearbyFn = (_) => [vA, vB];
      repo.byId['vA'] = vA;
      repo.byId['vB'] = vB;
      await pumpScreen(
        tester,
        overrides: [banquetRepositoryProvider.overrideWithValue(repo)],
      );
      seedDetails(container);
      container.read(eventDraftProvider.notifier)
        ..setVenueType(VenueType.banquetHall)
        ..setBanquetVenue(
          venueId: 'vA',
          venueName: 'Palace A',
          address: 'Palace A address',
          latitude: 17.44,
          longitude: 78.35,
          capacity: 500,
        );
      await applySeed(tester);

      // Valid card for the first hall.
      expect(find.text('Palace A'), findsWidgets);
      expect(find.text('Change venue'), findsOneWidget);

      await tester.tap(find.text('Change venue'));
      await tester.pumpAndSettle(); // picker with vA + vB
      expect(find.text('Palace B'), findsWidgets);

      await tester.tap(find.text('Palace B')); // pick the bigger hall
      await tester.pumpAndSettle(); // sheet closes, card re-validates vB

      final d = container.read(eventDraftProvider);
      expect(d.banquetVenueId, 'vB');
      expect(d.banquetVenueCapacity, 800); // captured for the cascade
      expect(find.text('Palace B'), findsWidgets); // card now shows vB
      await flushPersist(tester);
    });
  });
}
