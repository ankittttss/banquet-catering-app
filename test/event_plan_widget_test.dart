import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/collection.dart';
import 'package:banquet_catering_app/data/models/event_category.dart';
import 'package:banquet_catering_app/data/models/event_tier.dart';
import 'package:banquet_catering_app/data/models/menu_item.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/restaurant.dart';
import 'package:banquet_catering_app/data/models/user_address.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/features/user/screens/event_plan_screen.dart';
import 'package:banquet_catering_app/features/user/screens/user_home_screen.dart';
import 'package:banquet_catering_app/features/user/widgets/event_plan_chip.dart';
import 'package:banquet_catering_app/shared/providers/address_providers.dart';
import 'package:banquet_catering_app/shared/providers/auth_providers.dart';
import 'package:banquet_catering_app/shared/providers/banquet_providers.dart';
import 'package:banquet_catering_app/shared/providers/cart_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_tier_providers.dart';
import 'package:banquet_catering_app/shared/providers/home_providers.dart';
import 'package:banquet_catering_app/shared/providers/notification_providers.dart';

/// Phase 1 is READ-ONLY: the Event Plan page and its entry points must render
/// the plan honestly and mutate nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tierId = '00000000-0000-4000-8000-000000000111';
  const tier = EventTier(
    id: tierId,
    code: 'standard',
    label: 'Standard',
    description: '2 starters + 2 mains',
    perGuestMin: 250,
    perGuestMax: 400,
    sortOrder: 1,
  );

  late ProviderContainer container;

  /// Seeds a complete banquet plan on the real controller.
  void seedPlan(ProviderContainer c) {
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

  Future<GoRouter> pump(
    WidgetTester tester, {
    required Widget home,
    String initial = '/host',
    List<Override> overrides = const [],
    Size viewport = const Size(1000, 2200),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    container = ProviderContainer(
      overrides: [
        eventTiersProvider.overrideWith((_) async => const [tier]),
        selectedBanquetVenueCheckProvider.overrideWith(
          (_) async => const VenueCheck(VenueCheckState.valid),
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/host', builder: (_, __) => home),
        GoRoute(
          path: AppRoutes.eventPlan,
          builder: (_, __) => const EventPlanScreen(),
        ),
        GoRoute(
          path: AppRoutes.eventDetails,
          builder: (_, __) => const Scaffold(body: Text('DETAILS-SCREEN')),
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
    return router;
  }

  Widget chipHost() =>
      const Scaffold(body: Column(children: [EventPlanChip()]));

  group('entry point visibility', () {
    testWidgets('no meaningful draft → "Plan an event", not a plan summary',
        (tester) async {
      await pump(tester, home: chipHost());

      expect(find.text('Plan an event'), findsOneWidget);
      expect(find.text('Event plan'), findsNothing);
      // The draft controller schedules its persist debounce on build; flush it
      // so the timer doesn't outlive the widget tree.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('empty chip routes to Event Details, not a blank plan page',
        (tester) async {
      await pump(tester, home: chipHost());

      await tester.tap(find.text('Plan an event'));
      await tester.pumpAndSettle();
      expect(find.text('DETAILS-SCREEN'), findsOneWidget);
    });

    testWidgets('meaningful draft → chip shows the plan and opens it',
        (tester) async {
      await pump(tester, home: chipHost());
      seedPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Event plan'), findsOneWidget);

      await tester.tap(find.text('Event plan'));
      await tester.pumpAndSettle();
      expect(find.text('Grand Palace, Gachibowli'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 400)); // flush persist
    });
  });

  group('Event Plan page', () {
    testWidgets('deep-linked with no draft → "Plan an event" empty state',
        (tester) async {
      await pump(
        tester,
        home: const Scaffold(body: Text('HOST')),
        initial: AppRoutes.eventPlan,
      );

      // The empty state, never a blank summary.
      expect(find.text('Plan an event'), findsWidgets);
      expect(find.text('Banquet venue'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Plan an event'));
      await tester.pumpAndSettle();
      expect(find.text('DETAILS-SCREEN'), findsOneWidget);
    });

    testWidgets('renders every section for a complete banquet plan',
        (tester) async {
      await pump(
        tester,
        home: const Scaffold(body: Text('HOST')),
        initial: AppRoutes.eventPlan,
      );
      seedPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Event'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Package'), findsOneWidget);
      expect(find.text('Banquet venue'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget); // resolved tier label
      expect(find.text('Grand Palace'), findsOneWidget); // venue name
      expect(find.text('Ready to order'), findsOneWidget);
      // Banquet plans have no setup section.
      expect(find.text('Setup & equipment'), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('never claims ready while the tier list is loading',
        (tester) async {
      await pump(
        tester,
        home: const Scaffold(body: Text('HOST')),
        initial: AppRoutes.eventPlan,
        overrides: [
          // Never completes → permanent loading.
          eventTiersProvider
              .overrideWith((_) => Completer<List<EventTier>>().future),
        ],
      );
      seedPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ready to order'), findsNothing);
      expect(find.text('Checking…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('deactivated tier → needs attention, never ready',
        (tester) async {
      await pump(
        tester,
        home: const Scaffold(body: Text('HOST')),
        initial: AppRoutes.eventPlan,
        overrides: [
          eventTiersProvider.overrideWith((_) async => const <EventTier>[]),
        ],
      );
      seedPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ready to order'), findsNothing);
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('Package needs attention'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets(
        'long name / address / venue lay out on a phone width without '
        'overflow, and the page scrolls', (tester) async {
      const longName = 'The Grand Royal Maharaja Wedding Reception and '
          'Sangeet Celebration Extravaganza Evening';
      const longAddress = 'Plot 42, Survey No. 118/A, Kokapet Village, '
          'Gandipet Mandal, Ranga Reddy District, near the old stone bridge, '
          'Hyderabad, Telangana 500075, India';
      const longVenue = 'Sri Venkateswara Grand Convention Centre and Banquet '
          'Halls (Kokapet Branch, Gate 3)';

      // A real small-phone width is what actually surfaces horizontal overflow
      // (the default 1000px test surface hides it), and a short height forces
      // the list to scroll.
      await pump(
        tester,
        home: const Scaffold(body: Text('HOST')),
        initial: AppRoutes.eventPlan,
        viewport: const Size(360, 640),
      );
      final ctrl = container.read(eventDraftProvider.notifier);
      final d = DateTime.now().add(const Duration(days: 30));
      ctrl.setEventName(longName);
      ctrl.setSession('Dinner');
      ctrl.setDate(DateTime(d.year, d.month, d.day));
      ctrl.setStartTime(DateTime(d.year, d.month, d.day, 19));
      ctrl.setEventLocation(
        address: longAddress,
        latitude: 17.44,
        longitude: 78.35,
      );
      ctrl.setTier(tierId: tierId, tierCode: 'STANDARD');
      ctrl.setVenueType(VenueType.banquetHall);
      ctrl.setBanquetVenue(
        venueId: 'v1',
        venueName: longVenue,
        address: longAddress,
        latitude: 17.44,
        longitude: 78.35,
        capacity: 500,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The framework throws a RenderFlex overflow DURING layout, so a clean
      // pump means nothing overflowed. The address wraps inside its Expanded.
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Kokapet Village'), findsWidgets);

      // Genuinely scrollable on the short screen.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('live-check Retry actions', () {
    testWidgets('package Retry re-fetches the tier list and recovers',
        (tester) async {
      var calls = 0;
      await pump(
        tester,
        home: const Scaffold(body: Text('HOST')),
        initial: AppRoutes.eventPlan,
        overrides: [
          eventTiersProvider.overrideWith((_) async {
            calls++;
            if (calls == 1) throw Exception('tier service down');
            return const [tier];
          }),
        ],
      );
      seedPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // First attempt failed → error state + Retry, never ready.
      expect(calls, 1);
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Ready to order'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Second call ran and the plan recovered.
      expect(calls, 2);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Ready to order'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('venue Retry re-runs the venue check and recovers',
        (tester) async {
      var calls = 0;
      await pump(
        tester,
        home: const Scaffold(body: Text('HOST')),
        initial: AppRoutes.eventPlan,
        overrides: [
          selectedBanquetVenueCheckProvider.overrideWith((_) async {
            calls++;
            if (calls == 1) throw Exception('venue lookup down');
            return const VenueCheck(VenueCheckState.valid);
          }),
        ],
      );
      seedPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(calls, 1);
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(calls, 2);
      expect(find.text('Ready to order'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('private-property plan', () {
    testWidgets('shows property and setup sections, hides banquet venue',
        (tester) async {
      await pump(
        tester,
        home: const Scaffold(body: Text('HOST')),
        initial: AppRoutes.eventPlan,
      );
      final ctrl = container.read(eventDraftProvider.notifier);
      final d = DateTime.now().add(const Duration(days: 30));
      ctrl.setEventName('Housewarming');
      ctrl.setSession('Lunch');
      ctrl.setDate(DateTime(d.year, d.month, d.day));
      ctrl.setStartTime(DateTime(d.year, d.month, d.day, 12));
      ctrl.setEventLocation(
        address: '12 Rose Villa, Jubilee Hills',
        latitude: 17.43,
        longitude: 78.40,
      );
      ctrl.setTier(tierId: tierId, tierCode: 'STANDARD');
      ctrl.setVenueType(VenueType.privateProperty);
      ctrl.setPropertyType(PropertyType.farmhouse);
      ctrl.setPropertyAddress(
        line1: '12 Rose Villa',
        cityPincode: 'Hyderabad 500033',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Private property'), findsOneWidget);
      expect(find.text('Setup & equipment'), findsOneWidget);
      expect(find.text('Banquet venue'), findsNothing);
      expect(find.textContaining('Farmhouse'), findsOneWidget);
      expect(find.text('None selected'), findsOneWidget); // no add-ons yet
      expect(find.text('Ready to order'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('home card promises what it actually does', () {
    /// Pumps the REAL home screen (and therefore the real draft card), with
    /// every unrelated section stubbed out.
    Future<GoRouter> pumpHome(
      WidgetTester tester, {
      Size viewport = const Size(1000, 2200),
    }) =>
        pump(
          tester,
          home: const UserHomeScreen(),
          viewport: viewport,
          overrides: [
            addressesProvider.overrideWith((_) async => const <UserAddress>[]),
            currentProfileProvider.overrideWith((_) async => null),
            eventCategoriesProvider
                .overrideWith((_) async => const <EventCategory>[]),
            collectionsProvider.overrideWith((_) async => const <Collection>[]),
            homeRestaurantsProvider.overrideWith(
              (_) => const AsyncValue<List<Restaurant>>.data(<Restaurant>[]),
            ),
            unreadNotificationCountProvider.overrideWith((_) => 0),
          ],
        );

    testWidgets('ready plan → card text describes opening the Event Plan',
        (tester) async {
      await pumpHome(tester);
      seedPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The card must NOT promise food selection while it opens the plan.
      expect(find.text('View your complete event plan'), findsOneWidget);
      expect(find.textContaining('add dishes'), findsNothing);
      // Home owns its event surface via the draft card — the chip is not also
      // stacked here (that would repeat date/guests and the same tap target).
      expect(find.byType(EventPlanChip), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets(
        'a very long event name is single-line + ellipsised on the card',
        (tester) async {
      // NB: asserted via the Text config, not a pixel overflow check. Flutter's
      // widget-test placeholder font renders every glyph as a fixed wide box,
      // so even short meta strings ("Thu, 20 Aug · 7:00 PM") falsely "overflow"
      // at phone widths — a pixel assertion here would be a font artifact, not
      // a real defect. The ellipsis config is what actually protects long
      // names, and that IS verifiable.
      const longName =
          'The Grand Royal Maharaja Wedding Reception and Sangeet Celebration '
          'Extravaganza Evening at the Palace';
      await pumpHome(tester);
      final ctrl = container.read(eventDraftProvider.notifier);
      ctrl.setEventName(longName);
      ctrl.setSession('Dinner');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final title = tester.widget<Text>(find.text(longName));
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('ready plan → tapping the card opens the Event Plan',
        (tester) async {
      await pumpHome(tester);
      seedPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('View your complete event plan'));
      await tester.pumpAndSettle();

      // Asserted on the rendered screen: go_router's currentConfiguration.uri
      // reports the last DECLARATIVE location and does not reflect imperative
      // pushes, so it cannot verify this navigation.
      expect(find.byType(EventPlanScreen), findsOneWidget);
      // And the plan page independently says food selection can continue.
      expect(find.textContaining('add dishes'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('incomplete plan → card still shows the cascade hint',
        (tester) async {
      await pumpHome(tester);
      // Everything except a venue.
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
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pick a banquet venue to finish'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('Phase 1 is read-only', () {
    testWidgets('opening and leaving the plan mutates nothing at all',
        (tester) async {
      await pump(tester, home: chipHost());
      seedPlan(container);
      // Seed a cart too — it must survive untouched.
      final cart = container.read(cartProvider.notifier);
      cart.add(const MenuItem(
        id: 'm1',
        restaurantId: 'r1',
        categoryId: 'c1',
        name: 'Paneer Tikka',
        price: 220,
      ));
      cart.add(const MenuItem(
        id: 'm2',
        restaurantId: 'r1',
        categoryId: 'c1',
        name: 'Dal Makhani',
        price: 180,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // flush persist

      // Full snapshots, not a hand-picked subset of fields.
      final draftBefore =
          jsonEncode(container.read(eventDraftProvider).toJson());
      final cartBefore = container
          .read(cartProvider)
          .map((l) => '${l.signature}x${l.qty}@${l.item.price}')
          .toList();
      await tester.tap(find.text('Event plan'));
      await tester.pumpAndSettle();
      expect(find.byType(EventPlanScreen), findsOneWidget); // on the page

      // The page uses its own leading IconButton, not a platform BackButton.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      final draftAfter =
          jsonEncode(container.read(eventDraftProvider).toJson());
      final cartAfter = container
          .read(cartProvider)
          .map((l) => '${l.signature}x${l.qty}@${l.item.price}')
          .toList();

      expect(draftAfter, draftBefore, reason: 'EventDraft must be identical');
      expect(cartAfter, cartBefore, reason: 'cart must be identical');

      // Navigation is asserted on the rendered tree, because go_router's
      // currentConfiguration.uri does not reflect imperative pushes.
      expect(
        find.byType(EventPlanScreen),
        findsNothing,
        reason: 'must have left the plan page',
      );
      // Back on the originating screen, exactly once — a duplicate would mean
      // the round trip stacked a second copy instead of popping.
      expect(
        find.byType(EventPlanChip),
        findsOneWidget,
        reason: 'no duplicate originating route left on the stack',
      );
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
