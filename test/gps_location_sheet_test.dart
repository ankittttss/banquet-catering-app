import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/core/services/location_service.dart';
import 'package:banquet_catering_app/core/services/photon_geocoder.dart';
import 'package:banquet_catering_app/data/models/user_address.dart';
import 'package:banquet_catering_app/features/user/widgets/address_search_sheet.dart';
import 'package:banquet_catering_app/shared/providers/address_providers.dart';
import 'package:banquet_catering_app/shared/providers/location_providers.dart';

/// GPS is scoped to the approved planning flows: the sheet only offers it when
/// the caller opts in with `allowCurrentLocation: true`.
void main() {
  /// Pumps a host screen whose button opens the sheet, and records the result.
  Future<GeocodeResult? Function()> pumpSheet(
    WidgetTester tester, {
    required CurrentLocationResolver gps,
    required bool allowCurrentLocation,
  }) async {
    GeocodeResult? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Keep the pre-search state trivial + offline.
          addressesProvider.overrideWith((_) async => const <UserAddress>[]),
          currentLocationProvider.overrideWithValue(gps),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await AddressSearchSheet.show(
                    context,
                    allowCurrentLocation: allowCurrentLocation,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  testWidgets('planning flow: GPS success pops the resolved location',
      (tester) async {
    final read = await pumpSheet(
      tester,
      allowCurrentLocation: true,
      gps: () async => ResolvedAddress(
        lat: 17.44,
        lng: 78.35,
        line1: 'HITEC City',
        city: 'Hyderabad',
      ),
    );

    expect(find.text('Use my current location'), findsOneWidget);
    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();

    final captured = read();
    expect(captured, isNotNull);
    expect(captured!.latitude, 17.44);
    expect(captured.longitude, 78.35);
    expect(captured.displayAddress, contains('HITEC City'));
  });

  testWidgets('permission denied shows a message and keeps manual search',
      (tester) async {
    final read = await pumpSheet(
      tester,
      allowCurrentLocation: true,
      gps: () async => throw LocationException(LocationError.permissionDenied),
    );
    expect(read(), isNull);

    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();

    expect(find.textContaining('permission denied'), findsOneWidget);
    // The sheet stays open — manual address search is still available.
    expect(find.byType(TextField), findsOneWidget);
    expect(read(), isNull);
  });

  testWidgets('location service off shows the turn-it-on message',
      (tester) async {
    await pumpSheet(
      tester,
      allowCurrentLocation: true,
      gps: () async => throw LocationException(LocationError.serviceDisabled),
    );

    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Location is off'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
      'NON-planning flow: GPS is not offered and the device is never asked',
      (tester) async {
    var gpsCalls = 0;
    await pumpSheet(
      tester,
      allowCurrentLocation: false, // e.g. the saved address book
      gps: () async {
        gpsCalls++;
        return ResolvedAddress(lat: 17.44, lng: 78.35);
      },
    );

    // No affordance at all → permission can never be prompted from here.
    expect(find.text('Use my current location'), findsNothing);
    expect(gpsCalls, 0);
    // Manual search is still fully available.
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('GPS defaults to OFF when the caller does not opt in',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressesProvider.overrideWith((_) async => const <UserAddress>[]),
          currentLocationProvider.overrideWithValue(
            () async => ResolvedAddress(lat: 1, lng: 1),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                // No allowCurrentLocation argument → must default to false.
                onPressed: () => AddressSearchSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Use my current location'), findsNothing);
  });
}
