import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/event_draft.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/features/user/planning_next_step.dart';

void main() {
  // A draft with all the event-details basics filled (steps 1–5 done), ready
  // to branch on the venue. Overrides move only the venue-stage fields.
  EventDraft basicsDone({
    VenueType? venueType,
    String? banquetVenueId,
    PrivatePropertyDraft? propertyDraft,
  }) =>
      EventDraft(
        eventName: 'Aanya Sangeet',
        session: 'Dinner',
        date: DateTime(2026, 8, 20),
        startTime: DateTime(2026, 8, 20, 19, 0),
        endTime: DateTime(2026, 8, 20, 22, 0),
        location: 'Grand Palace, Gachibowli',
        tierId: 'tier-standard',
        tierCode: 'STANDARD',
        venueType: venueType,
        banquetVenueId: banquetVenueId,
        propertyDraft: propertyDraft,
      );

  const completeProperty = PrivatePropertyDraft(
    type: PropertyType.home,
    addressLine1: '12 Rose Villa',
    cityPincode: 'Hyderabad 500081',
  );

  group('unfinished basics all route to event details', () {
    test('empty draft', () {
      expect(
        planningNextStep(const EventDraft()).route,
        AppRoutes.eventDetails,
      );
    });

    test('has session but no date', () {
      expect(
        planningNextStep(const EventDraft(session: 'Dinner')).route,
        AppRoutes.eventDetails,
      );
    });

    test('everything but the package/tier', () {
      final d = EventDraft(
        session: 'Dinner',
        date: DateTime(2026, 8, 20),
        startTime: DateTime(2026, 8, 20, 19, 0),
        endTime: DateTime(2026, 8, 20, 22, 0),
        location: 'Grand Palace',
        // tierId intentionally omitted
      );
      final step = planningNextStep(d);
      expect(step.route, AppRoutes.eventDetails);
      expect(step.hint, 'Pick a tier that fits your budget');
    });
  });

  group('venue branch', () {
    test('basics done, no venue type → venue-type screen', () {
      final step = planningNextStep(basicsDone());
      expect(step.route, AppRoutes.eventVenueType);
      expect(step.hint, 'Choose your venue type');
    });

    test('banquet hall chosen, no venue picked → venue-type screen', () {
      final step =
          planningNextStep(basicsDone(venueType: VenueType.banquetHall));
      expect(step.route, AppRoutes.eventVenueType);
      expect(step.hint, 'Pick a banquet venue to finish');
    });

    test('private property chosen, details incomplete → property screen', () {
      final step =
          planningNextStep(basicsDone(venueType: VenueType.privateProperty));
      expect(step.route, AppRoutes.eventProperty);
    });
  });

  group('fully planned → browse restaurants on home', () {
    test('banquet hall with a venue picked', () {
      final step = planningNextStep(
        basicsDone(venueType: VenueType.banquetHall, banquetVenueId: 'v1'),
      );
      expect(step.route, AppRoutes.userHome);
      expect(step.hint, 'Add dishes to finalise the menu');
    });

    test('private property with complete details', () {
      final step = planningNextStep(
        basicsDone(
          venueType: VenueType.privateProperty,
          propertyDraft: completeProperty,
        ),
      );
      expect(step.route, AppRoutes.userHome);
    });
  });
}
