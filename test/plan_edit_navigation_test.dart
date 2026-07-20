import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/addon.dart';
import 'package:banquet_catering_app/data/models/event_category.dart';
import 'package:banquet_catering_app/data/models/event_tier.dart';
import 'package:banquet_catering_app/data/models/menu_item.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/user_address.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/features/user/plan_edit_context.dart';
import 'package:banquet_catering_app/features/user/screens/event_details_screen.dart';
import 'package:banquet_catering_app/features/user/widgets/address_search_sheet.dart';
import 'package:banquet_catering_app/features/user/screens/event_plan_screen.dart';
import 'package:banquet_catering_app/features/user/screens/setup_equipment_screen.dart';
import 'package:banquet_catering_app/shared/providers/addon_providers.dart';
import 'package:banquet_catering_app/shared/providers/address_providers.dart';
import 'package:banquet_catering_app/shared/providers/banquet_providers.dart';
import 'package:banquet_catering_app/shared/providers/cart_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_tier_providers.dart';
import 'package:banquet_catering_app/shared/providers/home_providers.dart';

/// Phase 2 navigation: query-param edit mode, edit-mode return (Done / AppBar
/// back / system back) for pushed and direct-entry routes, deferred sections
/// not exposed, and zero mutation on open+return. Assertions are on the
/// rendered tree, since go_router's currentConfiguration.uri does not reflect
/// imperative pushes.
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
  const weddingCat = EventCategory(
    id: 'c1',
    slug: 'wedding',
    name: 'Wedding',
    emoji: '💍',
    iconName: 'favorite',
    bgHex: '#FFF3E0',
    iconHex: '#E5A100',
    sortOrder: 1,
  );

  late ProviderContainer container;

  void seedCommon(EventDraftController ctrl) {
    final d = DateTime.now().add(const Duration(days: 30));
    ctrl.setEventName('Aanya Sangeet');
    ctrl.setSession('Dinner');
    ctrl.setDate(DateTime(d.year, d.month, d.day));
    ctrl.setStartTime(DateTime(d.year, d.month, d.day, 19));
    ctrl.setEventLocation(
      address: 'Rose Villa, Jubilee Hills',
      latitude: 17.43,
      longitude: 78.40,
    );
    ctrl.setTier(tierId: tierId, tierCode: 'STANDARD');
  }

  void seedBanquetPlan(ProviderContainer c) {
    final ctrl = c.read(eventDraftProvider.notifier);
    seedCommon(ctrl);
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

  void seedPrivatePlan(ProviderContainer c) {
    final ctrl = c.read(eventDraftProvider.notifier);
    seedCommon(ctrl);
    ctrl.setVenueType(VenueType.privateProperty);
    ctrl.setPropertyType(PropertyType.farmhouse);
    ctrl.setPropertyAddress(
      line1: '12 Rose Villa',
      cityPincode: 'Hyderabad 500033',
    );
  }

  /// A complete banquet plan whose tier id is [tierIdValue] (used to seed a
  /// missing/deactivated selection).
  void seedBanquetWithTier(ProviderContainer c, String tierIdValue) {
    final ctrl = c.read(eventDraftProvider.notifier);
    final d = DateTime.now().add(const Duration(days: 30));
    ctrl.setEventName('Aanya Sangeet');
    ctrl.setSession('Dinner');
    ctrl.setDate(DateTime(d.year, d.month, d.day));
    ctrl.setStartTime(DateTime(d.year, d.month, d.day, 19));
    ctrl.setEventLocation(
      address: 'Rose Villa, Jubilee Hills',
      latitude: 17.43,
      longitude: 78.40,
    );
    ctrl.setTier(tierId: tierIdValue, tierCode: 'X');
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

  MenuItem menuItem(String id, String name, double price,
          {bool isVeg = true}) =>
      MenuItem(
        id: id,
        restaurantId: 'r1',
        categoryId: 'cat1',
        name: name,
        price: price,
        isVeg: isVeg,
      );

  Future<GoRouter> pump(
    WidgetTester tester, {
    required String initial,
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
        eventCategoriesProvider.overrideWith((_) async => const [weddingCat]),
        addressesProvider.overrideWith((_) async => const <UserAddress>[]),
        addonCatalogProvider.overrideWithValue(const <Addon>[]),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: AppRoutes.eventPlan,
          builder: (_, __) => const EventPlanScreen(),
        ),
        GoRoute(
          path: AppRoutes.eventDetails,
          builder: (_, __) => const EventDetailsScreen(),
        ),
        GoRoute(
          path: AppRoutes.eventSetup,
          builder: (_, __) => const SetupEquipmentScreen(),
        ),
        GoRoute(
          path: AppRoutes.userHome,
          builder: (_, __) => const Scaffold(body: Text('HOME-SCREEN')),
        ),
        GoRoute(
          path: AppRoutes.eventVenueType,
          builder: (_, __) => const Scaffold(body: Text('VENUE-SCREEN')),
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

  Finder editButtons() => find.widgetWithText(TextButton, 'Edit');
  Finder doneButton() => find.widgetWithText(FilledButton, 'Done');

  /// Simulate the OS/system back button (hardware/gesture back).
  Future<void> systemBack(WidgetTester tester) =>
      tester.binding.handlePopRoute();

  group('edit → Done → return', () {
    testWidgets('Event Plan → Edit Event → Done → same plan, no duplicate',
        (tester) async {
      await pump(tester, initial: AppRoutes.eventPlan);
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(EventPlanScreen), findsOneWidget);

      await tester.tap(editButtons().first); // Event is the first section
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailsScreen), findsOneWidget);
      expect(find.text('Edit event'), findsOneWidget);

      await tester.tap(doneButton());
      await tester.pumpAndSettle();
      expect(find.byType(EventPlanScreen), findsOneWidget);
      expect(find.byType(EventDetailsScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('direct deep-link edit → Done → falls back to the Event Plan',
        (tester) async {
      await pump(tester, initial: PlanEditContext.editEvent());
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(EventDetailsScreen), findsOneWidget);
      expect(find.text('Edit event'), findsOneWidget);

      await tester.tap(doneButton());
      await tester.pumpAndSettle();
      expect(find.byType(EventPlanScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('Setup edit (private) → Done → returns to the plan',
        (tester) async {
      await pump(tester, initial: AppRoutes.eventPlan);
      seedPrivatePlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Setup is the last Edit on a private plan (Event, Package, Setup).
      await tester.tap(editButtons().last);
      await tester.pumpAndSettle();
      expect(find.byType(SetupEquipmentScreen), findsOneWidget);
      expect(find.text('Edit setup'), findsOneWidget);

      await tester.tap(doneButton());
      await tester.pumpAndSettle();
      expect(find.byType(EventPlanScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('package section scroll on a normal phone', () {
    testWidgets(
        'Edit Package brings the package section into view (390x844) '
        'after the tier list loads', (tester) async {
      await pump(
        tester,
        initial: AppRoutes.eventPlan,
        viewport: const Size(390, 844),
      );
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(editButtons().at(1)); // Package is the second Edit
      await tester.pumpAndSettle(); // nav + async tiers + scroll animation
      expect(find.byType(EventDetailsScreen), findsOneWidget);

      final title = find.text('Choose a package');
      expect(title, findsOneWidget);
      final r = tester.getRect(title);
      // Brought within the 844-tall viewport — not left below the fold.
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.top, lessThan(844));
      expect(r.bottom, lessThanOrEqualTo(844));
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('normal planning is unchanged', () {
    testWidgets(
        'no source → title is "Plan your event", Continue runs the '
        'forward cascade (not a return to the plan)', (tester) async {
      await pump(tester, initial: AppRoutes.eventDetails);
      seedBanquetPlan(container); // complete → next step is browse (userHome)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Plan your event'), findsOneWidget);
      expect(find.text('Edit event'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.text('HOME-SCREEN'), findsOneWidget);
      expect(find.byType(EventPlanScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('back behaviour (pushed + direct)', () {
    testWidgets('pushed edit: AppBar back returns to the plan', (tester) async {
      await pump(tester, initial: AppRoutes.eventPlan);
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(editButtons().first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(EventPlanScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('pushed edit: system back returns to the plan', (tester) async {
      await pump(tester, initial: AppRoutes.eventPlan);
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(editButtons().first);
      await tester.pumpAndSettle();

      await systemBack(tester);
      await tester.pumpAndSettle();
      expect(find.byType(EventPlanScreen), findsOneWidget);
      expect(find.byType(EventDetailsScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('direct edit: AppBar back falls back to the plan',
        (tester) async {
      await pump(tester, initial: PlanEditContext.editEvent());
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(EventPlanScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('direct edit: system back falls back to the plan',
        (tester) async {
      await pump(tester, initial: PlanEditContext.editEvent());
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await systemBack(tester);
      await tester.pumpAndSettle();
      expect(find.byType(EventPlanScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('repeated round trips do not stack routes', () {
    testWidgets('3× Edit Event → Done leaves one plan, no Home/duplicate',
        (tester) async {
      await pump(tester, initial: AppRoutes.eventPlan);
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      for (var i = 0; i < 3; i++) {
        await tester.tap(editButtons().first);
        await tester.pumpAndSettle();
        expect(find.byType(EventDetailsScreen), findsOneWidget);
        await tester.tap(doneButton());
        await tester.pumpAndSettle();
      }
      expect(find.byType(EventPlanScreen), findsOneWidget);
      expect(find.byType(EventDetailsScreen), findsNothing);
      expect(find.text('HOME-SCREEN'), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('deferred sections are not editable', () {
    testWidgets('banquet plan → Edit only on Event + Package (2)',
        (tester) async {
      await pump(tester, initial: AppRoutes.eventPlan);
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Location and Banquet venue have no Edit action.
      expect(editButtons(), findsNWidgets(2));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets(
        'private plan → Edit on Event + Package + Setup (3), not '
        'property or location', (tester) async {
      await pump(tester, initial: AppRoutes.eventPlan);
      seedPrivatePlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(editButtons(), findsNWidgets(3));
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('occasion + location are read-only in edit mode only', () {
    // Asserted by BEHAVIOUR (does the mutation fire?), not by counting
    // IgnorePointers — the framework wraps widgets in its own IgnorePointers,
    // so a structural count is unreliable.
    testWidgets(
        'edit mode: tapping occasion does not mutate; tapping location '
        'does not open the picker', (tester) async {
      await pump(tester, initial: PlanEditContext.editEvent());
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final sessionBefore = container.read(eventDraftProvider).session;
      // Occasion: setCategory (which rewrites session + guests) must NOT fire.
      await tester.tap(find.text('Wedding'), warnIfMissed: false);
      await tester.pump();
      expect(container.read(eventDraftProvider).categorySlug, isNull);
      expect(container.read(eventDraftProvider).session, sessionBefore);

      // Location: the address picker must NOT open. (For a banquet plan the
      // location is the venue address.)
      await tester.tap(
        find.text('Grand Palace, Gachibowli'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(find.byType(AddressSearchSheet), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('normal mode: tapping an occasion DOES mutate the draft',
        (tester) async {
      await pump(tester, initial: AppRoutes.eventDetails); // no source
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(eventDraftProvider).categorySlug, isNull);
      await tester.tap(find.text('Wedding'));
      await tester.pump();
      expect(container.read(eventDraftProvider).categorySlug, 'wedding');
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('package is never auto-selected in edit mode', () {
    const deadUuid = '99999999-9999-4999-8999-999999999999';
    const legacyId = 'standard'; // legacy non-database id, not in the live list

    Future<void> openEditPackage(
        WidgetTester tester, String tierIdValue) async {
      await pump(tester, initial: PlanEditContext.editPackage());
      seedBanquetWithTier(container, tierIdValue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200)); // tiers load
    }

    testWidgets('a DEACTIVATED tier id is not reconciled on open + return',
        (tester) async {
      await openEditPackage(tester, deadUuid);
      // Not silently replaced with the first active tier on open.
      expect(container.read(eventDraftProvider).tierId, deadUuid);

      await tester.tap(doneButton());
      await tester.pumpAndSettle();
      expect(container.read(eventDraftProvider).tierId, deadUuid);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('a MISSING/legacy tier id is not reconciled on open + return',
        (tester) async {
      await openEditPackage(tester, legacyId);
      expect(container.read(eventDraftProvider).tierId, legacyId);

      await tester.tap(doneButton());
      await tester.pumpAndSettle();
      expect(container.read(eventDraftProvider).tierId, legacyId);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets(
        'normal planning STILL auto-selects a valid default (unchanged)',
        (tester) async {
      await pump(tester, initial: AppRoutes.eventDetails); // no source
      seedBanquetWithTier(container, deadUuid);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester
          .pump(const Duration(milliseconds: 100)); // post-frame setTier

      // Reconciled to the one active tier — normal-mode behaviour preserved.
      expect(container.read(eventDraftProvider).tierId, tierId);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('occasion + location expose no tap action in edit mode', () {
    bool hasTap(WidgetTester tester, Finder f) => tester
        .getSemantics(f)
        .getSemanticsData()
        .hasAction(SemanticsAction.tap);

    testWidgets('edit mode: no tap action for keyboard / assistive tech',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, initial: PlanEditContext.editEvent());
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(hasTap(tester, find.text('Wedding')), isFalse,
          reason: 'occasion tile must expose no tap action');
      expect(hasTap(tester, find.text('Grand Palace, Gachibowli')), isFalse,
          reason: 'location row must expose no tap action');
      handle.dispose();
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('normal mode: the tap action is present (interactive)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, initial: AppRoutes.eventDetails);
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(hasTap(tester, find.text('Wedding')), isTrue);
      expect(hasTap(tester, find.text('Grand Palace, Gachibowli')), isTrue);
      handle.dispose();
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('normal-mode location remains functional', () {
    testWidgets('tapping the location row opens the address picker',
        (tester) async {
      await pump(tester, initial: AppRoutes.eventDetails); // no source
      seedBanquetPlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AddressSearchSheet), findsNothing);
      await tester.tap(find.text('Grand Palace, Gachibowli'));
      await tester.pumpAndSettle();
      expect(find.byType(AddressSearchSheet), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('Setup edit back behaviour (pushed + direct)', () {
    // The setup screen uses PlanFlowHeader (chevron back), not an AppBar arrow.
    Finder setupBack() => find.byIcon(Icons.chevron_left_rounded);

    testWidgets('pushed: header back returns to the plan', (tester) async {
      await pump(tester, initial: AppRoutes.eventPlan);
      seedPrivatePlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(editButtons().last); // Setup
      await tester.pumpAndSettle();
      expect(find.byType(SetupEquipmentScreen), findsOneWidget);

      await tester.tap(setupBack());
      await tester.pumpAndSettle();
      expect(find.byType(EventPlanScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('pushed: system back returns to the plan', (tester) async {
      await pump(tester, initial: AppRoutes.eventPlan);
      seedPrivatePlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(editButtons().last);
      await tester.pumpAndSettle();

      await systemBack(tester);
      await tester.pumpAndSettle();
      expect(find.byType(EventPlanScreen), findsOneWidget);
      expect(find.byType(SetupEquipmentScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('direct: header back falls back to the plan', (tester) async {
      await pump(tester, initial: PlanEditContext.editSetup());
      seedPrivatePlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Edit setup'), findsOneWidget);

      await tester.tap(setupBack());
      await tester.pumpAndSettle();
      expect(find.byType(EventPlanScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('direct: system back falls back to the plan', (tester) async {
      await pump(tester, initial: PlanEditContext.editSetup());
      seedPrivatePlan(container);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await systemBack(tester);
      await tester.pumpAndSettle();
      expect(find.byType(EventPlanScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('zero mutation across Event / Package / Setup', () {
    testWidgets(
        'open + return leaves the draft AND a real 2-line cart '
        'byte-identical', (tester) async {
      await pump(tester, initial: AppRoutes.eventPlan);
      seedPrivatePlan(container); // has Event, Package and Setup edits
      final cart = container.read(cartProvider.notifier);
      // Two real lines: different quantities AND a customization.
      cart.add(menuItem('m1', 'Paneer Tikka', 220));
      cart.add(menuItem('m1', 'Paneer Tikka', 220)); // → qty 2 (same signature)
      cart.add(
        menuItem('m2', 'Chicken Biryani', 320, isVeg: false),
        customization: const CartCustomization(notes: 'Extra spicy'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // flush persist

      // Full, meaningful snapshots — not just list length.
      String snapDraft() =>
          jsonEncode(container.read(eventDraftProvider).toJson());
      String snapCart() => container
          .read(cartProvider)
          .map((l) => '${l.item.id}|q${l.qty}|p${l.item.price}'
              '|veg=${l.item.isVeg}|${l.portion.name}'
              '|${l.spice.name}|${l.notes}')
          .join(';');

      final draft0 = snapDraft();
      final cart0 = snapCart();
      // Sanity: the cart genuinely has two lines with different quantities.
      final lines = container.read(cartProvider);
      expect(lines, hasLength(2));
      expect(lines.firstWhere((l) => l.item.id == 'm1').qty, 2);
      expect(lines.firstWhere((l) => l.item.id == 'm2').qty, 1);

      Future<void> roundTrip(int editIndex, Type screen) async {
        await tester.tap(editButtons().at(editIndex));
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget);
        await tester.tap(doneButton());
        await tester.pumpAndSettle();
        expect(snapDraft(), draft0,
            reason: 'draft changed after edit $editIndex');
        expect(snapCart(), cart0, reason: 'cart changed after edit $editIndex');
      }

      await roundTrip(0, EventDetailsScreen); // Event
      await roundTrip(1, EventDetailsScreen); // Package
      await roundTrip(2, SetupEquipmentScreen); // Setup
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
