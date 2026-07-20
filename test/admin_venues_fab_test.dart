import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:banquet_catering_app/data/models/banquet_venue.dart';
import 'package:banquet_catering_app/data/models/user_profile.dart';
import 'package:banquet_catering_app/features/admin/screens/admin_venues_screen.dart';
import 'package:banquet_catering_app/features/admin/widgets/admin_ui.dart';
import 'package:banquet_catering_app/shared/providers/banquet_providers.dart';

/// Geometry regression for the pinned "Add venue" button: it must stay inside
/// the mobile viewport with a real margin, and the venue list must reserve
/// enough bottom padding that the button never covers the last card.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const screen = Size(390, 844); // typical phone logical size

  BanquetVenue venue(int i) => BanquetVenue(
        id: 'v$i',
        ownerProfileId: 'op',
        name: 'Venue $i',
        address: 'Address $i',
        latitude: 17.4,
        longitude: 78.4,
        capacity: 200,
      );

  Future<void> pumpVenues(
    WidgetTester tester, {
    required int count,
    double bottomPadding = 0,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    // dpr is 1.0, so physical == logical here.
    tester.view.padding = FakeViewPadding(bottom: bottomPadding);
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        adminVenuesProvider.overrideWith(
          (ref) async => [for (var i = 1; i <= count; i++) venue(i)],
        ),
        banquetOperatorsProvider
            .overrideWith((ref) async => const <UserProfile>[]),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/admin/venues',
      routes: [
        GoRoute(
          path: '/admin/venues',
          builder: (_, __) => const AdminVenuesScreen(),
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
    await tester.pump(const Duration(milliseconds: 100)); // venues resolve
  }

  testWidgets('button is pinned inside the viewport with a real margin',
      (tester) async {
    await pumpVenues(tester, count: 12);

    final fab = find.byType(AdminFab);
    expect(fab, findsOneWidget);

    final r = tester.getRect(fab);
    // Fully inside the screen on both axes …
    expect(r.bottom, lessThanOrEqualTo(screen.height));
    expect(r.right, lessThanOrEqualTo(screen.width));
    expect(r.top, greaterThanOrEqualTo(0));
    // … and inset by the configured margin (no safe-area inset in tests, so
    // the gap is exactly the margin).
    expect(screen.height - r.bottom, closeTo(AdminScaffold.fabMargin, 0.5));
    expect(screen.width - r.right, closeTo(AdminScaffold.fabMargin, 0.5));
  });

  testWidgets('scrolled to the end, the button does not cover the last card',
      (tester) async {
    await pumpVenues(tester, count: 12);

    // Scroll the list fully to the bottom.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    final lastCard = find.text('Venue 12');
    expect(lastCard, findsOneWidget);

    final cardRect = tester.getRect(lastCard);
    final fabRect = tester.getRect(find.byType(AdminFab));
    // The reserved bottom padding must push the final card clear of the
    // button — no overlap, and the card is still on screen.
    expect(cardRect.bottom, lessThanOrEqualTo(fabRect.top));
    expect(cardRect.bottom, lessThanOrEqualTo(screen.height));
  });

  testWidgets(
      'with a gesture-bar safe area the button clears it and still does not '
      'cover the last card', (tester) async {
    // Simulate a phone with a bottom gesture bar / system nav.
    const inset = 34.0;
    await pumpVenues(tester, count: 12, bottomPadding: inset);

    final fabRect = tester.getRect(find.byType(AdminFab));
    // The button must sit ABOVE the system inset, not under it.
    expect(
      screen.height - fabRect.bottom,
      greaterThanOrEqualTo(inset + AdminScaffold.fabMargin - 0.5),
    );

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    final cardRect = tester.getRect(find.text('Venue 12'));
    expect(cardRect.bottom, lessThanOrEqualTo(fabRect.top));
  });

  testWidgets('button still renders on the empty state', (tester) async {
    await pumpVenues(tester, count: 0);

    expect(find.text('No venues yet'), findsOneWidget);
    expect(find.byType(AdminFab), findsOneWidget);
    final r = tester.getRect(find.byType(AdminFab));
    expect(r.bottom, lessThanOrEqualTo(screen.height));
  });
}
