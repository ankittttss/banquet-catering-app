import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/event_category.dart';
import 'package:banquet_catering_app/data/models/event_tier.dart';
import 'package:banquet_catering_app/data/models/user_address.dart';
import 'package:banquet_catering_app/features/user/screens/event_details_screen.dart';
import 'package:banquet_catering_app/shared/providers/address_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_tier_providers.dart';
import 'package:banquet_catering_app/shared/providers/home_providers.dart';

/// Focused Event Details widget test — provider overrides only, zero real
/// network. Covers: the Continue gate (shared cascade), explicit session
/// selection, and the latest typed guest value being committed on Continue.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tier = EventTier(
    id: '00000000-0000-0000-0000-000000000001',
    code: 'standard',
    label: 'Standard',
    description: '2 starters + 2 mains',
    perGuestMin: 250,
    perGuestMax: 400,
    sortOrder: 1,
  );

  late ProviderContainer container;
  late GoRouter router;

  Future<void> pumpScreen(
    WidgetTester tester, {
    Override? tiersOverride,
  }) async {
    // Tall test surface so the lazy ListView builds every section including
    // the Continue button — the default 800×600 viewport never builds it.
    tester.view.physicalSize = const Size(1000, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [
        // No network: categories resolve to an empty list (section shows its
        // honest empty text), tiers to one UUID tier unless a test swaps in
        // a loading/error/empty variant.
        eventCategoriesProvider
            .overrideWith((_) async => const <EventCategory>[]),
        tiersOverride ??
            eventTiersProvider.overrideWith((_) async => const [tier]),
        // Cuts the auth/Supabase chain out of the initState address prefill.
        addressesProvider.overrideWith((_) async => const <UserAddress>[]),
      ],
    );
    addTearDown(container.dispose);
    router = GoRouter(
      initialLocation: AppRoutes.eventDetails,
      routes: [
        GoRoute(
          path: AppRoutes.eventDetails,
          builder: (_, __) => const EventDetailsScreen(),
        ),
        GoRoute(
          path: AppRoutes.eventVenueType,
          builder: (_, __) => const Scaffold(body: Text('VENUE-SCREEN')),
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
    await tester.pump(); // first frame
    await tester.pump(const Duration(milliseconds: 400)); // futures + fades
  }

  /// Seed everything EXCEPT session, with a schedule that's valid on the
  /// real clock (tests can't inject `now` into the widget; a far-future
  /// date keeps this deterministic in practice).
  void seedAllButSession(ProviderContainer c) {
    final ctrl = c.read(eventDraftProvider.notifier);
    final d = DateTime.now().add(const Duration(days: 30));
    ctrl.setEventName('Widget Test Event');
    ctrl.setDate(DateTime(d.year, d.month, d.day));
    ctrl.setStartTime(DateTime(d.year, d.month, d.day, 19));
    ctrl.setEventLocation(
      address: 'Grand Palace, Gachibowli',
      latitude: 17.44,
      longitude: 78.35,
    );
    // Tier auto-selects from the overridden provider post-frame; session is
    // deliberately left null.
  }

  /// Everything filled INCLUDING session; tier set explicitly when given
  /// (otherwise the picker's auto-select handles it once tiers load).
  void seedComplete(ProviderContainer c, {String? tierId}) {
    seedAllButSession(c);
    final ctrl = c.read(eventDraftProvider.notifier);
    ctrl.setSession('Dinner');
    if (tierId != null) ctrl.setTier(tierId: tierId, tierCode: 'X');
  }

  Finder continueButton() => find.widgetWithText(FilledButton, 'Continue');

  FilledButton buttonWidget(WidgetTester tester) =>
      tester.widget<FilledButton>(continueButton());

  testWidgets(
      'gate: Continue disabled with a session hint until a session chip is '
      'tapped, then navigates to the venue screen', (tester) async {
    await pumpScreen(tester);
    seedAllButSession(container);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50)); // tier auto-select

    // Disabled + the cascade's session hint is shown under the button.
    var button = tester.widget<FilledButton>(continueButton());
    expect(button.onPressed, isNull);
    expect(find.textContaining('session'), findsWidgets);

    // Explicit session selection (D3) — chips exist even with no category.
    await tester.ensureVisible(find.text('High Tea'));
    await tester.tap(find.text('High Tea'));
    await tester.pump();
    expect(container.read(eventDraftProvider).session, 'High Tea');

    button = tester.widget<FilledButton>(continueButton());
    expect(button.onPressed, isNotNull);

    await tester.ensureVisible(continueButton());
    await tester.tap(continueButton());
    await tester.pumpAndSettle();
    expect(find.text('VENUE-SCREEN'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400)); // flush persist
  });

  testWidgets(
      'guest commit: a value typed WITHOUT unfocusing is what Continue uses',
      (tester) async {
    await pumpScreen(tester);
    seedAllButSession(container);
    container.read(eventDraftProvider.notifier).setSession('Dinner');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The guest field is the small numeric TextField showing the count.
    final guestField = find.widgetWithText(TextField, '50');
    expect(guestField, findsOneWidget);
    await tester.ensureVisible(guestField);
    await tester.enterText(guestField, '123'); // NO unfocus, NO submit

    await tester.ensureVisible(continueButton());
    await tester.tap(continueButton());
    await tester.pumpAndSettle();

    // The draft carries the typed value — not the stale pre-edit count —
    // and navigation followed the cascade to the venue screen.
    expect(container.read(eventDraftProvider).guestCount, 123);
    expect(find.text('VENUE-SCREEN'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400)); // flush persist
  });

  group('tier gate — loading / error / empty / invalid selections', () {
    const deadUuid = '99999999-9999-9999-9999-999999999999';

    testWidgets(
        'tiers still LOADING → Continue disabled even with a '
        'uuid-shaped (unverifiable) selection', (tester) async {
      final never = Completer<List<EventTier>>(); // never completes
      await pumpScreen(
        tester,
        tiersOverride: eventTiersProvider.overrideWith((_) => never.future),
      );
      seedComplete(container, tierId: deadUuid);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(buttonWidget(tester).onPressed, isNull);
      expect(find.textContaining('Loading packages'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400)); // flush persist
    });

    testWidgets('tier fetch ERROR → Continue disabled, Retry visible',
        (tester) async {
      await pumpScreen(
        tester,
        tiersOverride: eventTiersProvider
            .overrideWith((_) async => throw Exception('supabase down')),
      );
      seedComplete(container, tierId: deadUuid);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(buttonWidget(tester).onPressed, isNull);
      expect(find.textContaining("Couldn't load packages"), findsWidgets);
      expect(find.text('Retry'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('tier list EMPTY → Continue disabled', (tester) async {
      await pumpScreen(
        tester,
        tiersOverride:
            eventTiersProvider.overrideWith((_) async => const <EventTier>[]),
      );
      seedComplete(container, tierId: deadUuid);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(buttonWidget(tester).onPressed, isNull);
      expect(find.textContaining('No packages available'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets(
        'invalid uuid selection AFTER tiers load is reconciled to the '
        'first active tier and Continue proceeds', (tester) async {
      await pumpScreen(tester); // default: one active tier
      seedComplete(container, tierId: deadUuid);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // auto-replace

      // Reconciled: the dead uuid was swapped for the real active tier.
      expect(container.read(eventDraftProvider).tierId, tier.id);
      expect(buttonWidget(tester).onPressed, isNotNull);

      await tester.ensureVisible(continueButton());
      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(find.text('VENUE-SCREEN'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
