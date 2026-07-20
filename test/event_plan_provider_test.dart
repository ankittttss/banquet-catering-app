import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/data/models/event_tier.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/features/user/event_plan_summary.dart';
import 'package:banquet_catering_app/shared/providers/addon_providers.dart';
import 'package:banquet_catering_app/shared/providers/banquet_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_plan_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';
import 'package:banquet_catering_app/shared/providers/event_tier_providers.dart';

/// The summary provider must not do work the draft cannot possibly need: an
/// untouched draft should cost zero lookups, a private-property plan should
/// never hit the banquet check, and so on. These tests count real invocations
/// through recording overrides.
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

  late int tierCalls;
  late int venueCalls;
  late int addonCalls;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tierCalls = 0;
    venueCalls = 0;
    addonCalls = 0;
    container = ProviderContainer(
      overrides: [
        eventTiersProvider.overrideWith((_) async {
          tierCalls++;
          return const [tier];
        }),
        selectedBanquetVenueCheckProvider.overrideWith((_) async {
          venueCalls++;
          return const VenueCheck(VenueCheckState.valid);
        }),
        addonsCountProvider.overrideWith((_) {
          addonCalls++;
          return 0;
        }),
      ],
    );
  });

  tearDown(() => container.dispose());

  EventDraftController ctrl() => container.read(eventDraftProvider.notifier);

  /// Keeps the summary subscribed the way a screen would.
  EventPlanSummary read() {
    final sub = container.listen(eventPlanSummaryProvider, (_, __) {});
    addTearDown(sub.close);
    return container.read(eventPlanSummaryProvider);
  }

  test('empty draft → no tier, venue or add-on lookup at all', () {
    final s = read();
    expect(s.readiness, EventPlanReadiness.notStarted);
    expect(tierCalls, 0);
    expect(venueCalls, 0);
    expect(addonCalls, 0);
  });

  test('no tier selected → tier list is never fetched', () {
    ctrl().setSession('Dinner'); // meaningful, but no tier
    final s = read();
    expect(s.packageCheck, EventPlanCheck.attention);
    expect(s.packageText, 'No package selected');
    expect(tierCalls, 0);
  });

  test('tier selected → tier list IS fetched', () {
    ctrl().setSession('Dinner');
    ctrl().setTier(tierId: tierId, tierCode: 'STANDARD');
    read();
    expect(tierCalls, 1);
  });

  test('private-property plan → banquet venue check is never invoked', () {
    ctrl().setSession('Dinner');
    ctrl().setVenueType(VenueType.privateProperty);
    ctrl().setPropertyType(PropertyType.home);
    final s = read();
    expect(s.venueCheck, EventPlanCheck.notApplicable);
    expect(venueCalls, 0);
  });

  test('banquet WITHOUT a venue → no by-id venue lookup', () {
    ctrl().setSession('Dinner');
    ctrl().setVenueType(VenueType.banquetHall);
    final s = read();
    expect(s.venueCheck, EventPlanCheck.attention);
    expect(s.venueText, 'No venue selected');
    expect(venueCalls, 0);
  });

  test('banquet WITH a venue → the by-id venue lookup runs', () {
    ctrl().setSession('Dinner');
    ctrl().setVenueType(VenueType.banquetHall);
    ctrl().setBanquetVenue(
      venueId: 'v1',
      venueName: 'Grand Palace',
      address: 'Grand Palace, Gachibowli',
      latitude: 17.44,
      longitude: 78.35,
      capacity: 500,
    );
    read();
    expect(venueCalls, 1);
  });

  test('add-on count is read only for a private-property plan', () {
    ctrl().setSession('Dinner');
    ctrl().setVenueType(VenueType.banquetHall);
    read();
    expect(addonCalls, 0, reason: 'banquet summaries show no add-ons');

    ctrl().setVenueType(VenueType.privateProperty);
    read();
    expect(addonCalls, greaterThan(0));
  });
}
