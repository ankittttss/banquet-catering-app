import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/event_draft.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/features/user/planning_next_step.dart';

void main() {
  // Fixed IST business-clock "now" so every schedule assertion is
  // deterministic forever.
  final now = DateTime(2026, 8, 1, 12, 0); // 1 Aug 2026, 12:00 IST

  PlanningStep step(EventDraft d) => planningNextStep(d, now: now);

  /// Fully planned BANQUET draft; overrides knock out one piece at a time.
  EventDraft draft({
    String? eventName = 'Aanya Sangeet',
    String? session = 'Dinner',
    DateTime? date,
    bool withDate = true,
    bool withTimes = true,
    DateTime? startTime,
    DateTime? endTime,
    String? location = 'Grand Palace, Gachibowli',
    double? lat = 17.44,
    double? lng = 78.35,
    int guestCount = 50,
    String? tierId = '00000000-0000-4000-8000-000000000111',
    VenueType? venueType = VenueType.banquetHall,
    String? banquetVenueId = 'v1',
    int? banquetVenueCapacity,
    PrivatePropertyDraft? propertyDraft,
  }) {
    final d = date ?? DateTime(2026, 8, 20);
    return EventDraft(
      eventName: eventName,
      session: session,
      date: withDate ? d : null,
      startTime: withTimes
          ? (startTime ?? DateTime(d.year, d.month, d.day, 19))
          : null,
      endTime:
          withTimes ? (endTime ?? DateTime(d.year, d.month, d.day, 22)) : null,
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
  }

  group('IST business clock representation (regression)', () {
    test(
        'nowInIst is a timezone-NEUTRAL wall-clock value — a utc-flagged '
        'DateTime here compares epochs against local draft times and '
        'wrongly blocks valid same-day events', () {
      final ist = nowInIst();
      // The original bug: .toUtc().add(5h30) keeps isUtc == true. This
      // assertion fails against that implementation on EVERY machine.
      expect(ist.isUtc, isFalse);
      // And the wall-clock fields genuinely represent IST (UTC + 5:30).
      final expected =
          DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
      final drift = DateTime(
        expected.year,
        expected.month,
        expected.day,
        expected.hour,
        expected.minute,
        expected.second,
      ).difference(ist).inSeconds.abs();
      expect(drift, lessThan(5));
    });

    test(
        'REAL clock, no injected now: an event starting 90 min from IST-now '
        'is never schedule-blocked (fails on IST devices with the utc-flag '
        'bug, where +90 min still compared as already passed)', () {
      final ist = nowInIst();
      // Built EXACTLY like the real UI builds draft times: a plain LOCAL
      // wall-clock DateTime constructed from IST components. Deriving the
      // start via nowInIst().add(...) would have inherited the broken
      // implementation's UTC flag and hidden the original mismatch.
      final start = DateTime(ist.year, ist.month, ist.day, ist.hour, ist.minute)
          .add(const Duration(minutes: 90));
      final d = draft(
        date: DateTime(start.year, start.month, start.day),
        startTime: start,
        endTime: start.add(const Duration(hours: 2)),
      );
      // No `now:` injection — this exercises the production clock path.
      final s = planningNextStep(d);
      expect(s.hint, isNot(contains('passed')));
      expect(s.route, AppRoutes.userHome); // fully planned
    });
  });

  group('cascade order — event-details fields', () {
    test('empty draft → name first', () {
      final s = step(const EventDraft());
      expect(s.route, AppRoutes.eventDetails);
      expect(s.hint, contains('Name your event'));
    });

    test('missing session', () {
      final s = step(draft(session: null));
      expect(s.route, AppRoutes.eventDetails);
      expect(s.hint.toLowerCase(), contains('session'));
    });

    test('missing date', () {
      expect(step(draft(withDate: false)).route, AppRoutes.eventDetails);
    });

    test('missing times', () {
      final s = step(draft(withTimes: false));
      expect(s.route, AppRoutes.eventDetails);
      expect(s.hint, contains('start & end time'));
    });

    test('missing location', () {
      expect(step(draft(location: null)).route, AppRoutes.eventDetails);
    });

    test('coordinates unconfirmed', () {
      final s = step(draft(lat: null, lng: null));
      expect(s.route, AppRoutes.eventDetails);
      expect(s.hint, contains('Confirm your event location'));
    });

    test('missing tier', () {
      final s = step(draft(tierId: null));
      expect(s.route, AppRoutes.eventDetails);
      expect(s.hint.toLowerCase(), contains('tier'));
    });

    test(
        'legacy fallback tier ids from restored drafts are STRUCTURALLY '
        'incomplete on the shared cascade (Home/Checkout, no tier list '
        'needed)', () {
      for (final legacy in ['budget', 'standard', 'premium']) {
        final s = step(draft(tierId: legacy));
        expect(s.route, AppRoutes.eventDetails,
            reason: 'legacy id "$legacy" must not count as a tier');
        expect(s.hint.toLowerCase(), contains('tier'));
      }
    });

    test('isUuidShapedTierId accepts real uuids, rejects legacy ids', () {
      expect(
          isUuidShapedTierId('00000000-0000-4000-8000-000000000111'), isTrue);
      expect(isUuidShapedTierId('budget'), isFalse);
      expect(isUuidShapedTierId('tier-standard'), isFalse);
    });
  });

  group('schedule validity (IST business clock)', () {
    test('past date → back to event details with schedule hint', () {
      final s = step(draft(date: DateTime(2026, 7, 20))); // before Aug 1
      expect(s.route, AppRoutes.eventDetails);
      expect(s.hint, contains('date has passed'));
    });

    test('same-day start already passed', () {
      final s = step(draft(
        date: DateTime(2026, 8, 1),
        startTime: DateTime(2026, 8, 1, 11, 0), // now is 12:00
        endTime: DateTime(2026, 8, 1, 14, 0),
      ));
      expect(s.route, AppRoutes.eventDetails);
      expect(s.hint, contains('start time has passed'));
    });

    test('same-day FUTURE start is valid', () {
      final s = step(draft(
        date: DateTime(2026, 8, 1),
        startTime: DateTime(2026, 8, 1, 19, 0),
        endTime: DateTime(2026, 8, 1, 22, 0),
      ));
      expect(s.route, AppRoutes.userHome); // fully planned
    });

    test('end at/before start (restored corrupt draft)', () {
      final s = step(draft(
        startTime: DateTime(2026, 8, 20, 19),
        endTime: DateTime(2026, 8, 20, 19),
      ));
      expect(s.route, AppRoutes.eventDetails);
      expect(s.hint, contains('End time must be after'));
    });
  });

  group('guest range 5–5000 (product range)', () {
    test('below minimum', () {
      final s = step(draft(guestCount: 4));
      expect(s.route, AppRoutes.eventDetails);
      expect(s.hint, contains('between 5 and 5000'));
    });

    test('above maximum', () {
      expect(step(draft(guestCount: 5001)).route, AppRoutes.eventDetails);
    });

    test('boundaries pass', () {
      expect(step(draft(guestCount: 5)).route, AppRoutes.userHome);
      expect(step(draft(guestCount: 5000)).route, AppRoutes.userHome);
    });
  });

  group('venue branch', () {
    test('details done, no venue type → venue-type screen', () {
      final s = step(draft(venueType: null, banquetVenueId: null));
      expect(s.route, AppRoutes.eventVenueType);
      expect(s.hint, 'Choose your venue type');
    });

    test('banquet hall chosen, no venue picked → venue-type screen', () {
      final s = step(draft(banquetVenueId: null));
      expect(s.route, AppRoutes.eventVenueType);
      expect(s.hint, 'Pick a banquet venue to finish');
    });

    test('private property, details incomplete → property screen', () {
      final s = step(draft(
        venueType: VenueType.privateProperty,
        banquetVenueId: null,
      ));
      expect(s.route, AppRoutes.eventProperty);
    });

    test(
        'banquet venue captured for a smaller party is re-opened once guests '
        'exceed its capacity (the venue id alone must NOT read as done)', () {
      final s = step(draft(guestCount: 300, banquetVenueCapacity: 200));
      expect(s.route, AppRoutes.eventVenueType);
      expect(s.hint, contains('no longer fits'));
    });

    test('a captured venue that still fits stays done → browse', () {
      final s = step(draft(guestCount: 150, banquetVenueCapacity: 200));
      expect(s.route, AppRoutes.userHome);
    });

    test('guests exactly at capacity still fit → browse', () {
      final s = step(draft(guestCount: 200, banquetVenueCapacity: 200));
      expect(s.route, AppRoutes.userHome);
    });

    test('unknown captured capacity (null) is never blocked → browse', () {
      final s = step(draft(guestCount: 4000, banquetVenueCapacity: null));
      expect(s.route, AppRoutes.userHome);
    });
  });

  group('fully planned → browse restaurants', () {
    test('banquet flow', () {
      final s = step(draft());
      expect(s.route, AppRoutes.userHome);
      expect(s.hint, 'Add dishes to finalise the menu');
    });

    test('private-property flow', () {
      final s = step(draft(
        venueType: VenueType.privateProperty,
        banquetVenueId: null,
        propertyDraft: const PrivatePropertyDraft(
          type: PropertyType.home,
          addressLine1: '12 Rose Villa',
          cityPincode: 'Hyderabad 500081',
        ),
      ));
      expect(s.route, AppRoutes.userHome);
    });
  });
}
