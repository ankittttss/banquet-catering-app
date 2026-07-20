import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/event_draft.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/features/user/checkout_guards.dart';

/// checkoutPlanningGap is a thin wrapper over planningNextStep (the shared
/// cascade, exhaustively covered in planning_next_step_test) — these tests
/// pin the wrapper contract: every incomplete flow blocks with the right
/// route, complete flows pass, and no saved address is ever involved.
void main() {
  final now = DateTime(2026, 8, 1, 12, 0); // fixed IST business clock

  EventDraft banquetDraft({
    String? eventName = 'Aanya Sangeet',
    String? session = 'Dinner',
    bool withDate = true,
    bool withTimes = true,
    String? location = 'Grand Palace, Gachibowli',
    double? lat = 17.44,
    double? lng = 78.35,
    String? tierId = '00000000-0000-4000-8000-000000000111',
    VenueType? venueType = VenueType.banquetHall,
    String? banquetVenueId = 'v1',
    int? banquetVenueCapacity,
    int guestCount = 50,
    PrivatePropertyDraft? propertyDraft,
  }) =>
      EventDraft(
        eventName: eventName,
        session: session,
        date: withDate ? DateTime(2026, 8, 20) : null,
        startTime: withTimes ? DateTime(2026, 8, 20, 19) : null,
        endTime: withTimes ? DateTime(2026, 8, 20, 22) : null,
        location: location,
        eventLatitude: lat,
        eventLongitude: lng,
        guestCount: guestCount,
        tierId: tierId,
        tierCode: tierId == null ? null : 'STANDARD',
        venueType: venueType,
        banquetVenueId: banquetVenueId,
        banquetVenueCapacity: banquetVenueCapacity,
        propertyDraft: propertyDraft,
      );

  const completeProperty = PrivatePropertyDraft(
    type: PropertyType.home,
    addressLine1: '12 Rose Villa',
    cityPincode: 'Hyderabad 500081',
  );

  group('checkoutPlanningGap', () {
    test('complete BANQUET flow is accepted', () {
      expect(checkoutPlanningGap(banquetDraft(), now: now), isNull);
    });

    test('complete PRIVATE-PROPERTY flow is accepted', () {
      final d = banquetDraft(
        venueType: VenueType.privateProperty,
        banquetVenueId: null,
        propertyDraft: completeProperty,
      );
      expect(checkoutPlanningGap(d, now: now), isNull);
    });

    test(
        'a fully planned event needs NO saved profile address — the guard '
        'takes only the draft (there is no address parameter at all)', () {
      expect(checkoutPlanningGap(banquetDraft(), now: now), isNull);
    });

    test('missing name → event details', () {
      final gap = checkoutPlanningGap(banquetDraft(eventName: null), now: now);
      expect(gap!.route, AppRoutes.eventDetails);
    });

    test('missing session → event details', () {
      final gap = checkoutPlanningGap(banquetDraft(session: null), now: now);
      expect(gap!.route, AppRoutes.eventDetails);
    });

    test('missing date → event details', () {
      final gap = checkoutPlanningGap(banquetDraft(withDate: false), now: now);
      expect(gap!.route, AppRoutes.eventDetails);
    });

    test('missing times are NOT silently defaulted → event details', () {
      final gap = checkoutPlanningGap(banquetDraft(withTimes: false), now: now);
      expect(gap!.route, AppRoutes.eventDetails);
      expect(gap.message, contains('start & end time'));
    });

    test('stale schedule (restored past-date draft) blocks checkout', () {
      final gap = checkoutPlanningGap(
        banquetDraft(),
        now: DateTime(2027, 1, 1), // business clock moved past the event
      );
      expect(gap, isNotNull);
      expect(gap!.route, AppRoutes.eventDetails);
      expect(gap.message, contains('has passed'));
    });

    test('missing tier → event details', () {
      final gap = checkoutPlanningGap(banquetDraft(tierId: null), now: now);
      expect(gap!.route, AppRoutes.eventDetails);
    });

    test('missing venue type → venue screen', () {
      final gap = checkoutPlanningGap(
        banquetDraft(venueType: null, banquetVenueId: null),
        now: now,
      );
      expect(gap!.route, AppRoutes.eventVenueType);
    });

    test('banquet flow without a venue → venue screen', () {
      final gap =
          checkoutPlanningGap(banquetDraft(banquetVenueId: null), now: now);
      expect(gap!.route, AppRoutes.eventVenueType);
    });

    test(
        'a venue picked earlier but now too small for the guest count blocks '
        'checkout → venue screen (no slipping through to place_order)', () {
      final gap = checkoutPlanningGap(
        banquetDraft(guestCount: 300, banquetVenueCapacity: 200),
        now: now,
      );
      expect(gap, isNotNull);
      expect(gap!.route, AppRoutes.eventVenueType);
      expect(gap.message, contains('no longer fits'));
    });

    test('a captured venue that still fits the party passes checkout', () {
      final gap = checkoutPlanningGap(
        banquetDraft(guestCount: 150, banquetVenueCapacity: 200),
        now: now,
      );
      expect(gap, isNull);
    });

    test('incomplete private-property details → property screen', () {
      final gap = checkoutPlanningGap(
        banquetDraft(
          venueType: VenueType.privateProperty,
          banquetVenueId: null,
          propertyDraft: const PrivatePropertyDraft(type: PropertyType.home),
        ),
        now: now,
      );
      expect(gap!.route, AppRoutes.eventProperty);
    });

    test('coordinates missing → blocked, home never stands in', () {
      final gap =
          checkoutPlanningGap(banquetDraft(lat: null, lng: null), now: now);
      expect(gap, isNotNull);
      expect(gap!.route, AppRoutes.eventDetails);
      expect(gap.message, contains('Confirm your event location'));
    });
  });
}
