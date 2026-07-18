import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/event_draft.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/features/user/checkout_guards.dart';

void main() {
  // Fully planned BANQUET event; overrides knock out one piece at a time.
  EventDraft banquetDraft({
    String? eventName = 'Aanya Sangeet',
    String? session = 'Dinner',
    bool withDate = true,
    bool withTimes = true,
    String? location = 'Grand Palace, Gachibowli',
    double? lat = 17.44,
    double? lng = 78.35,
    String? tierId = 'tier-standard',
    VenueType? venueType = VenueType.banquetHall,
    String? banquetVenueId = 'v1',
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
        tierId: tierId,
        tierCode: tierId == null ? null : 'STANDARD',
        venueType: venueType,
        banquetVenueId: banquetVenueId,
        propertyDraft: propertyDraft,
      );

  const completeProperty = PrivatePropertyDraft(
    type: PropertyType.home,
    addressLine1: '12 Rose Villa',
    cityPincode: 'Hyderabad 500081',
  );

  group('checkoutPlanningGap — every workflow gap blocks', () {
    test('complete BANQUET flow is accepted', () {
      expect(checkoutPlanningGap(banquetDraft()), isNull);
    });

    test(
        'a fully planned event needs NO saved profile address — the guard '
        'takes only the draft (there is no address parameter at all), so '
        'checkout can proceed for a customer with zero saved addresses', () {
      // Compile-time proof: checkoutPlanningGap(draft) has no address input.
      expect(checkoutPlanningGap(banquetDraft()), isNull);
    });

    test('complete PRIVATE-PROPERTY flow is accepted', () {
      final d = banquetDraft(
        venueType: VenueType.privateProperty,
        banquetVenueId: null,
        propertyDraft: completeProperty,
      );
      expect(checkoutPlanningGap(d), isNull);
    });

    test('missing name → event details', () {
      final gap = checkoutPlanningGap(banquetDraft(eventName: null));
      expect(gap, isNotNull);
      expect(gap!.route, AppRoutes.eventDetails);
    });

    test('missing session → event details', () {
      final gap = checkoutPlanningGap(banquetDraft(session: null));
      expect(gap!.route, AppRoutes.eventDetails);
    });

    test('missing date → event details', () {
      final gap = checkoutPlanningGap(banquetDraft(withDate: false));
      expect(gap!.route, AppRoutes.eventDetails);
    });

    test('missing times are NOT silently defaulted → event details', () {
      final gap = checkoutPlanningGap(banquetDraft(withTimes: false));
      expect(gap!.route, AppRoutes.eventDetails);
      expect(gap.message, contains('start & end time'));
    });

    test('missing tier → event details', () {
      final gap = checkoutPlanningGap(banquetDraft(tierId: null));
      expect(gap!.route, AppRoutes.eventDetails);
      expect(gap.message.toLowerCase(), contains('tier'));
    });

    test('missing venue type → venue screen', () {
      final gap = checkoutPlanningGap(
        banquetDraft(venueType: null, banquetVenueId: null),
      );
      expect(gap!.route, AppRoutes.eventVenueType);
    });

    test('banquet flow without a venue → venue screen', () {
      final gap = checkoutPlanningGap(banquetDraft(banquetVenueId: null));
      expect(gap!.route, AppRoutes.eventVenueType);
    });

    test('incomplete private-property details → property screen', () {
      final gap = checkoutPlanningGap(banquetDraft(
        venueType: VenueType.privateProperty,
        banquetVenueId: null,
        propertyDraft: const PrivatePropertyDraft(type: PropertyType.home),
      ));
      expect(gap!.route, AppRoutes.eventProperty);
    });

    test(
        'coordinates missing → blocked; the home address can never stand in '
        '(the guard never even sees an address)', () {
      final gap = checkoutPlanningGap(banquetDraft(lat: null, lng: null));
      expect(gap, isNotNull);
      expect(gap!.route, AppRoutes.eventDetails);
      expect(gap.message, contains('Confirm your event location'));
    });
  });
}
