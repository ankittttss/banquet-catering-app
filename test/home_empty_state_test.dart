import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/event_category.dart';
import 'package:banquet_catering_app/data/models/restaurant.dart';
import 'package:banquet_catering_app/data/models/user_address.dart';
import 'package:banquet_catering_app/features/user/screens/user_home_screen.dart';
import 'package:banquet_catering_app/shared/providers/address_providers.dart';
import 'package:banquet_catering_app/shared/providers/auth_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';
import 'package:banquet_catering_app/shared/providers/home_providers.dart';
import 'package:banquet_catering_app/shared/providers/notification_providers.dart';

/// An empty restaurant list has three very different causes. The screen must
/// name the real one and offer the way out — a generic "no restaurants yet"
/// reads as a broken app and hides the fix.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    container = ProviderContainer(
      overrides: [
        addressesProvider.overrideWith((_) async => const <UserAddress>[]),
        currentProfileProvider.overrideWith((_) async => null),
        eventCategoriesProvider
            .overrideWith((_) async => const <EventCategory>[]),
        // The whole point: the feed comes back empty.
        homeRestaurantsProvider.overrideWith(
          (_) => const AsyncValue<List<Restaurant>>.data(<Restaurant>[]),
        ),
        unreadNotificationCountProvider.overrideWith((_) => 0),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.userHome,
      routes: [
        GoRoute(
          path: AppRoutes.userHome,
          builder: (_, __) => const UserHomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.eventDetails,
          builder: (_, __) => const Scaffold(body: Text('DETAILS-SCREEN')),
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

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
      'a selected package that no kitchen serves says SO, and offers '
      'to change the package', (tester) async {
    await pumpHome(tester);
    container
        .read(eventDraftProvider.notifier)
        .setTier(tierId: 'tier-1', tierCode: 'BUDGET');
    await settle(tester);

    expect(find.text('No kitchens serve this package here'), findsOneWidget);
    expect(
        find.textContaining('offers the package you picked'), findsOneWidget);
    expect(find.text('Change package'), findsOneWidget);
    // Never the old generic copy that looked like a broken app.
    expect(find.text('No restaurants yet'), findsNothing);
  });

  testWidgets('an active sort filter is named, and can be cleared in place',
      (tester) async {
    await pumpHome(tester);
    container.read(homeSortProvider.notifier).state = HomeSort.veg;
    await settle(tester);

    expect(find.text('No kitchens match “Pure Veg”'), findsOneWidget);
    expect(find.text('Clear filter'), findsOneWidget);

    await tester.tap(find.text('Clear filter'));
    await settle(tester);
    expect(container.read(homeSortProvider), HomeSort.relevance);
  });

  testWidgets('no package and no filter → it is about the location',
      (tester) async {
    await pumpHome(tester);
    container.read(eventDraftProvider.notifier).setEventLocation(
          address: 'Haryana, India',
          latitude: 29,
          longitude: 76,
        );
    await settle(tester);

    // Names the place the customer actually chose.
    expect(find.textContaining('Haryana, India'), findsWidgets);
    expect(find.text('Change location'), findsOneWidget);

    await tester.tap(find.text('Change location'));
    await tester.pumpAndSettle();
    expect(find.text('DETAILS-SCREEN'), findsOneWidget);
  });

  testWidgets('a booked banquet hall is named, not addressed', (tester) async {
    await pumpHome(tester);
    container.read(eventDraftProvider.notifier)
      ..setEventLocation(
        address: 'Grand Palace, Gachibowli',
        latitude: 17.44,
        longitude: 78.35,
      )
      ..setBanquetVenue(
        venueId: 'v1',
        venueName: 'Grand Palace',
        address: 'Grand Palace, Gachibowli',
        latitude: 17.44,
        longitude: 78.35,
      );
    await settle(tester);

    // The empty state refers to the hall by NAME.
    expect(find.textContaining('“Grand Palace”'), findsWidgets);
  });
}
