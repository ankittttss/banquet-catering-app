import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/banquet_venue.dart';
import 'package:banquet_catering_app/data/models/menu_item.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/user_address.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/features/user/plan_edit_context.dart';
import 'package:banquet_catering_app/features/user/screens/event_details_screen.dart';
import 'package:banquet_catering_app/features/user/screens/event_plan_screen.dart';
import 'package:banquet_catering_app/features/user/screens/private_property_screen.dart';
import 'package:banquet_catering_app/features/user/screens/venue_type_screen.dart';
import 'package:banquet_catering_app/shared/providers/address_providers.dart';
import 'package:banquet_catering_app/shared/providers/banquet_providers.dart';
import 'package:banquet_catering_app/shared/providers/cart_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_tier_providers.dart';

/// The REAL Event Details screen is mounted on its own path so the stubbed
/// '/user/event' target stays free to prove we never navigate away to it.
const _realDetailsPath = '/real-details';

/// Phase 3: the Event Plan edit flows must be transactional — cancel changes
/// NOTHING, and every destructive step is confirmed first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tierId = '00000000-0000-4000-8000-000000000111';

  late ProviderContainer container;

  void seedBanquetPlan(ProviderContainer c) {
    final ctrl = c.read(eventDraftProvider.notifier);
    final d = DateTime.now().add(const Duration(days: 30));
    ctrl.setEventName('Aanya Sangeet');
    ctrl.setSession('Dinner');
    ctrl.setDate(DateTime(d.year, d.month, d.day));
    ctrl.setStartTime(DateTime(d.year, d.month, d.day, 19));
    ctrl.setEventLocation(
      address: 'Grand Palace, Gachibowli',
      latitude: 17.44,
      longitude: 78.35,
    );
    ctrl.setTier(tierId: tierId, tierCode: 'STANDARD');
    ctrl.setVenueType(VenueType.banquetHall);
    ctrl.setBanquetVenue(
      venueId: 'v1',
      venueName: 'Grand Palace',
      address: 'Grand Palace, Gachibowli',
      latitude: 17.44,
      longitude: 78.35,
      capacity: 500,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    String initial = AppRoutes.eventPlan,
    List<Override> overrides = const [],
    // Runs BEFORE the widget tree mounts, so state a screen's first-frame
    // callback reacts to (e.g. an existing cart) is already in place.
    void Function(ProviderContainer)? seedBeforeMount,
  }) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    container = ProviderContainer(
      overrides: [
        eventTiersProvider.overrideWith((_) async => const []),
        selectedBanquetVenueCheckProvider.overrideWith(
          (_) async => const VenueCheck(
            VenueCheckState.valid,
            venue: BanquetVenue(
              id: 'v1',
              ownerProfileId: 'op1',
              name: 'Grand Palace',
              address: 'Grand Palace, Gachibowli',
              latitude: 17.44,
              longitude: 78.35,
              capacity: 500,
            ),
          ),
        ),
        addressesProvider.overrideWith((_) async => const <UserAddress>[]),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    seedBeforeMount?.call(container);

    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: AppRoutes.eventPlan,
          builder: (_, __) => const EventPlanScreen(),
        ),
        GoRoute(
          path: AppRoutes.eventVenueType,
          builder: (_, __) => const VenueTypeScreen(),
        ),
        GoRoute(
          path: AppRoutes.eventDetails,
          builder: (_, __) => const Scaffold(body: Text('DETAILS-SCREEN')),
        ),
        GoRoute(
          path: _realDetailsPath,
          builder: (_, __) => const EventDetailsScreen(),
        ),
        GoRoute(
          path: AppRoutes.eventProperty,
          builder: (_, __) => const PrivatePropertyScreen(),
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
    await tester.pump(const Duration(milliseconds: 100));
  }

  String draftJson() => jsonEncode(container.read(eventDraftProvider).toJson());
  List<String> cartSigs() =>
      container.read(cartProvider).map((l) => l.signature).toList();

  void seedCart(ProviderContainer c) {
    final cart = c.read(cartProvider.notifier);
    cart.add(const MenuItem(
      id: 'm1',
      restaurantId: 'r1',
      categoryId: 'c1',
      name: 'Paneer Tikka',
      price: 220,
    ));
  }

  group('Start fresh', () {
    testWidgets('Cancel changes nothing and stays on the plan', (tester) async {
      await pump(tester);
      seedBanquetPlan(container);
      seedCart(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final draftBefore = draftJson();
      final cartBefore = cartSigs();

      await tester.tap(find.text('Start fresh'));
      await tester.pumpAndSettle();
      expect(find.text('Start fresh?'), findsOneWidget); // confirmation shown

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(draftJson(), draftBefore);
      expect(cartSigs(), cartBefore);
      expect(find.byType(EventPlanScreen), findsOneWidget); // still here
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('Confirm clears the draft + cart and opens Event Details',
        (tester) async {
      await pump(tester);
      seedBanquetPlan(container);
      seedCart(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Start fresh'));
      await tester.pumpAndSettle();
      // Confirm — the destructive action label inside the dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Start fresh'));
      await tester.pumpAndSettle();

      expect(find.text('DETAILS-SCREEN'), findsOneWidget); // navigated
      expect(container.read(cartProvider), isEmpty);
      expect(container.read(eventDraftProvider).eventName, isNull);
      expect(container.read(eventDraftProvider).banquetVenueId, isNull);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('Location change (candidate cancellation)', () {
    testWidgets('dismissing the address sheet mutates nothing', (tester) async {
      await pump(tester);
      seedBanquetPlan(container);
      seedCart(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final draftBefore = draftJson();
      final cartBefore = cartSigs();

      // Sections render Edit in tree order: Event, Location, Package, Venue.
      // The Location edit is the second.
      await tester.tap(find.text('Edit').at(1));
      await tester.pumpAndSettle();
      expect(find.text('Search an address'), findsOneWidget); // sheet open

      // Dismiss without choosing a candidate by tapping the scrim above the
      // sheet (the top ~15% of the screen is the modal barrier).
      await tester.tapAt(const Offset(400, 40));
      await tester.pumpAndSettle();
      expect(find.text('Search an address'), findsNothing); // sheet closed

      expect(draftJson(), draftBefore);
      expect(cartSigs(), cartBefore);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('Venue-type switching', () {
    // Enter the venue screen the real way: from a COMPLETE plan, tap the
    // "Banquet venue" section's Edit (the 4th Edit — Event, Location, Package,
    // Banquet venue). The venue screen loads network hero images whose futures
    // never settle in tests, so we drive it with discrete pumps, not
    // pumpAndSettle (which would time out on the pending image).
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> openVenueEdit(WidgetTester tester) async {
      await pump(tester);
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Edit').at(3));
      await settle(tester);
      expect(find.text('Edit venue'), findsOneWidget); // on the venue screen
    }

    testWidgets('switching banquet→private is confirmed; Cancel keeps banquet',
        (tester) async {
      await openVenueEdit(tester);

      // Tap the Private property card → a clear-what-you-lose confirmation.
      await tester.tap(find.text('Private property'));
      await settle(tester);
      expect(find.text('Switch to private property?'), findsOneWidget);
      expect(find.textContaining('Grand Palace'), findsWidgets);

      // The confirmation must say the event location goes too.
      expect(find.textContaining('event location'), findsWidgets);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      // Still a complete banquet plan — nothing switched, location intact.
      final draft = container.read(eventDraftProvider);
      expect(draft.venueType, VenueType.banquetHall);
      expect(draft.banquetVenueId, 'v1');
      expect(draft.location, 'Grand Palace, Gachibowli');
      expect(draft.eventLatitude, 17.44);
      expect(draft.hasEventCoords, isTrue);
    });

    testWidgets(
        'confirming clears the hall AND its location, then requires a new pin '
        'on the property step', (tester) async {
      await openVenueEdit(tester);

      await tester.tap(find.text('Private property'));
      await settle(tester);
      await tester.tap(find.text('Switch'));
      await settle(tester);

      final draft = container.read(eventDraftProvider);
      expect(draft.venueType, VenueType.privateProperty);
      expect(draft.banquetVenueId, isNull); // hall cleared
      // The hall's address/pin must not linger as the "private" location.
      expect(draft.location, isNull);
      expect(draft.hasEventCoords, isFalse);

      // Routed to the property step (in edit mode → "Done"), which stays gated
      // until a new pinned location is chosen.
      expect(find.text('Confirm your event location first'), findsOneWidget);
      final cont = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'));
      expect(cont.onPressed, isNull);
      // The cart is untouched until the new location is chosen + checked.
      expect(container.read(cartProvider), isEmpty);
    });
  });

  group('banquet→private replaces the venue step (no stale screen)', () {
    // The venue screen loads network hero images whose futures never settle in
    // tests, so drive it with discrete pumps rather than pumpAndSettle. Several
    // frames are needed for a route transition to finish AND the outgoing route
    // to be disposed.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    /// Tap Private property → Switch, landing on the property step.
    Future<void> switchToPrivate(WidgetTester tester) async {
      await tester.tap(find.text('Private property'));
      await settle(tester);
      await tester.tap(find.text('Switch'));
      await settle(tester);
      // We are on the property step and the venue step is GONE (replaced).
      expect(find.text('Confirm your event location first'), findsOneWidget);
      expect(find.byType(VenueTypeScreen), findsNothing);
    }

    /// Pushed entry: Event Plan → Edit venue (the 4th Edit) → switch.
    Future<void> openPushed(WidgetTester tester) async {
      await pump(tester, seedBeforeMount: seedBanquetPlan);
      await tester.tap(find.text('Edit').at(3));
      await settle(tester);
      expect(find.text('Edit venue'), findsOneWidget);
      await switchToPrivate(tester);
    }

    /// Direct entry: deep-linked straight onto the venue edit URL.
    Future<void> openDirect(WidgetTester tester) async {
      await pump(
        tester,
        initial: PlanEditContext.editVenue(),
        seedBeforeMount: seedBanquetPlan,
      );
      expect(find.text('Edit venue'), findsOneWidget);
      await switchToPrivate(tester);
    }

    void expectSingleEventPlan() {
      expect(find.byType(EventPlanScreen), findsOneWidget); // no duplicates
      expect(find.byType(VenueTypeScreen), findsNothing); // not underneath
      expect(find.byType(PrivatePropertyScreen), findsNothing);
    }

    testWidgets('pushed: header back lands on exactly one Event Plan',
        (tester) async {
      await openPushed(tester);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await settle(tester);
      expectSingleEventPlan();
    });

    testWidgets('pushed: system back lands on exactly one Event Plan',
        (tester) async {
      await openPushed(tester);
      tester.binding.handlePopRoute();
      await settle(tester);
      expectSingleEventPlan();
    });

    testWidgets('direct entry: header back falls back to one Event Plan',
        (tester) async {
      await openDirect(tester);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await settle(tester);
      expectSingleEventPlan();
    });

    testWidgets('direct entry: system back falls back to one Event Plan',
        (tester) async {
      await openDirect(tester);
      tester.binding.handlePopRoute();
      await settle(tester);
      expectSingleEventPlan();
    });

    testWidgets(
        'pushed: going back a SECOND time cannot resurface the venue '
        'step or stack another plan', (tester) async {
      await openPushed(tester);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await settle(tester);
      expectSingleEventPlan();

      // Back again from the plan — never a stale banquet screen underneath,
      // and never a second stacked plan.
      tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(VenueTypeScreen), findsNothing);
      expect(find.byType(EventPlanScreen), findsOneWidget);
    });
  });

  group('private → banquet is reachable again', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    void seedPrivatePlan(ProviderContainer c) {
      final ctrl = c.read(eventDraftProvider.notifier);
      final d = DateTime.now().add(const Duration(days: 30));
      ctrl.setEventName('Housewarming');
      ctrl.setSession('Lunch');
      ctrl.setDate(DateTime(d.year, d.month, d.day));
      ctrl.setStartTime(DateTime(d.year, d.month, d.day, 12));
      ctrl.setEventLocation(
        address: 'Jubilee Hills, Hyderabad',
        latitude: 17.43,
        longitude: 78.40,
      );
      ctrl.setTier(tierId: tierId, tierCode: 'STANDARD');
      ctrl.setVenueType(VenueType.privateProperty);
      ctrl.setPropertyType(PropertyType.farmhouse);
    }

    testWidgets(
        'a private plan exposes a Venue type edit that opens the '
        'venue screen', (tester) async {
      await pump(tester, seedBeforeMount: seedPrivatePlan);

      // The row exists at all — without it there is NO path back.
      expect(find.text('Venue type'), findsOneWidget);
      expect(find.text('Private property'), findsWidgets);

      // Edit order for a private plan: Event, Location, Package, Venue type,
      // Private property, Setup.
      await tester.tap(find.text('Edit').at(3));
      await settle(tester);
      expect(find.text('Edit venue'), findsOneWidget);
    });

    testWidgets('switching private → banquet hall works end to end',
        (tester) async {
      await pump(tester, seedBeforeMount: seedPrivatePlan);
      await tester.tap(find.text('Edit').at(3));
      await settle(tester);

      // Choosing the hall clears the private-property branch, so it confirms.
      await tester.tap(find.text('Banquet hall'));
      await settle(tester);
      if (find.text('Switch').evaluate().isNotEmpty) {
        await tester.tap(find.text('Switch'));
        await settle(tester);
      }

      final draft = container.read(eventDraftProvider);
      expect(draft.venueType, VenueType.banquetHall);
      expect(draft.propertyDraft, isNull); // private branch dropped
      // The searched location survives — no hall was ever selected.
      expect(draft.location, 'Jubilee Hills, Hyderabad');
      expect(draft.hasEventCoords, isTrue);
    });
  });

  group('venue picker has no transactional bypass', () {
    testWidgets(
        '"Change location" runs the transactional flow instead of jumping to '
        'Event Details', (tester) async {
      // A pinned plan with NO halls nearby → the picker offers to change the
      // event location, which used to jump straight to Event Details and
      // mutate the location with no cart/venue impact check.
      await pump(
        tester,
        initial: AppRoutes.eventVenueType,
        overrides: [
          nearbyVenuesProvider
              .overrideWith((_) async => const <BanquetVenue>[]),
        ],
      );
      final ctrl = container.read(eventDraftProvider.notifier);
      final d = DateTime.now().add(const Duration(days: 30));
      ctrl.setEventName('Aanya Sangeet');
      ctrl.setSession('Dinner');
      ctrl.setDate(DateTime(d.year, d.month, d.day));
      ctrl.setStartTime(DateTime(d.year, d.month, d.day, 19));
      ctrl.setEventLocation(
        address: 'Grand Palace, Gachibowli',
        latitude: 17.44,
        longitude: 78.35,
      );
      ctrl.setTier(tierId: tierId, tierCode: 'STANDARD');
      ctrl.setVenueType(VenueType.banquetHall);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Continue opens the picker (no venue selected yet).
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Change location'), findsOneWidget);

      await tester.tap(find.text('Change location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The transactional address flow opens; no bypass to Event Details.
      expect(find.text('Search an address'), findsOneWidget);
      expect(find.text('DETAILS-SCREEN'), findsNothing);
    });
  });

  group('private property is anchored to the confirmed event location', () {
    testWidgets('no pinned event location → address entry is gated',
        (tester) async {
      await pump(tester, initial: AppRoutes.eventProperty);
      final ctrl = container.read(eventDraftProvider.notifier);
      ctrl.setVenueType(VenueType.privateProperty);
      ctrl.setEventLocation(address: 'Community Hall'); // no coordinates
      ctrl.setPropertyType(PropertyType.farmhouse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Confirm your event location first'), findsOneWidget);
      expect(find.text('Set event location'), findsOneWidget);
      // No free-text address fields to contradict the (missing) pin.
      expect(find.byType(TextField), findsNothing);
      // And the step cannot be completed.
      final done = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Setup & equipment'),
      );
      expect(done.onPressed, isNull);
    });

    testWidgets(
        'pinned event location → city/area is read-only and stored from the '
        'confirmed location, never typed', (tester) async {
      await pump(tester, initial: AppRoutes.eventProperty);
      final ctrl = container.read(eventDraftProvider.notifier);
      ctrl.setVenueType(VenueType.privateProperty);
      ctrl.setEventLocation(
        address: 'Jubilee Hills, Hyderabad',
        latitude: 17.43,
        longitude: 78.40,
      );
      ctrl.setPropertyType(PropertyType.farmhouse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The confirmed location is shown as the anchor, not an editable field.
      expect(find.text('Jubilee Hills, Hyderabad'), findsOneWidget);
      expect(find.text('From your confirmed event location.'), findsOneWidget);
      // Only line 1 + landmark are typeable — no competing city/pincode input.
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.enterText(find.byType(TextField).first, '12 Rose Villa');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final property = container.read(eventDraftProvider).propertyDraft!;
      expect(property.addressLine1, '12 Rose Villa');
      // Anchored: the stored city/area IS the confirmed event location.
      expect(property.cityPincode, 'Jubilee Hills, Hyderabad');
    });

    testWidgets('a cleared property cannot be restored from stale controllers',
        (tester) async {
      await pump(tester, initial: AppRoutes.eventProperty);
      final ctrl = container.read(eventDraftProvider.notifier);
      ctrl.setVenueType(VenueType.privateProperty);
      ctrl.setEventLocation(
        address: 'Jubilee Hills, Hyderabad',
        latitude: 17.43,
        longitude: 78.40,
      );
      ctrl.setPropertyType(PropertyType.farmhouse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(find.byType(TextField).first, '12 Rose Villa');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        container.read(eventDraftProvider).propertyDraft!.addressLine1,
        '12 Rose Villa',
      );

      // A confirmed location change clears the property address details.
      ctrl.setEventLocation(
        address: 'Banjara Hills, Hyderabad',
        latitude: 17.41,
        longitude: 78.44,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Committing again (tapping outside a field) must NOT write the stale
      // building detail back onto the NEW location.
      await tester.tap(find.text('What kind of place?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final p = container.read(eventDraftProvider).propertyDraft!;
      expect(p.addressLine1, anyOf(isNull, isEmpty));
      expect(p.cityPincode, 'Banjara Hills, Hyderabad'); // re-anchored
    });
  });

  group('Event Details has no direct location mutation', () {
    /// Entry from Home/Cart/Checkout lands on Event Details in NORMAL mode.
    Future<void> openDetails(WidgetTester tester) async {
      await pump(tester, initial: _realDetailsPath);
      seedBanquetPlan(container);
      seedCart(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets(
        'normal-mode location row opens the transactional flow, and cancelling '
        'mutates nothing', (tester) async {
      await openDetails(tester);
      final draftBefore = draftJson();
      final cartBefore = cartSigs();

      // The location row shows the booked hall by NAME, not its address.
      await tester.tap(find.text('Grand Palace').last);
      await tester.pumpAndSettle();
      // The transactional address sheet — not a direct write.
      expect(find.text('Search an address'), findsOneWidget);

      await tester.tapAt(const Offset(400, 40)); // dismiss the sheet
      await tester.pumpAndSettle();

      // Candidate cancelled → the plan and cart are untouched.
      expect(draftJson(), draftBefore);
      expect(cartSigs(), cartBefore);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('automatic address prefill is never a silent location change', () {
    UserAddress addr({double? lat, double? lng}) => UserAddress(
          id: 'a1',
          userId: 'u1',
          label: AddressLabel.home,
          fullAddress: '12 Rose Villa, Hyderabad',
          latitude: lat,
          longitude: lng,
        );

    Future<void> openFresh(WidgetTester tester, UserAddress active) async {
      await pump(
        tester,
        initial: _realDetailsPath,
        overrides: [activeAddressProvider.overrideWith((_) => active)],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('a PINNED active address prefills a fresh, empty plan',
        (tester) async {
      await openFresh(tester, addr(lat: 17.43, lng: 78.40));
      final d = container.read(eventDraftProvider);
      expect(d.location, '12 Rose Villa, Hyderabad');
      expect(d.hasEventCoords, isTrue);
    });

    testWidgets('a COORDINATE-LESS active address is never applied',
        (tester) async {
      await openFresh(tester, addr()); // no pin
      expect(container.read(eventDraftProvider).location, isNull);
    });

    testWidgets('a (0,0) active address is never applied', (tester) async {
      await openFresh(tester, addr(lat: 0, lng: 0));
      expect(container.read(eventDraftProvider).location, isNull);
    });

    testWidgets(
        'prefill is skipped when a cart already exists (it would '
        'silently invalidate lines)', (tester) async {
      await pump(
        tester,
        initial: _realDetailsPath,
        overrides: [
          activeAddressProvider
              .overrideWith((_) => addr(lat: 17.43, lng: 78.40)),
        ],
        // The cart must exist BEFORE the screen's first-frame prefill runs.
        seedBeforeMount: seedCart,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(eventDraftProvider).location, isNull);
      expect(container.read(cartProvider), hasLength(1)); // untouched
    });
  });
}
