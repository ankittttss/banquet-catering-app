import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/features/user/checkout_guards.dart';
import 'package:banquet_catering_app/features/user/planning_next_step.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  EventDraftController ctrl() => container.read(eventDraftProvider.notifier);

  group('switching away from a selected banquet venue', () {
    test('clears the hall AND the event location it set (no stale hall pin)',
        () {
      ctrl().setVenueType(VenueType.banquetHall);
      ctrl().setBanquetVenue(
        venueId: 'v1',
        venueName: 'Grand Palace',
        address: 'Grand Palace, Gachibowli',
        latitude: 17.44,
        longitude: 78.35,
        capacity: 500,
      );
      // The hall IS the event location at this point.
      expect(container.read(eventDraftProvider).location,
          'Grand Palace, Gachibowli');

      ctrl().setVenueType(VenueType.privateProperty);

      final d = container.read(eventDraftProvider);
      expect(d.banquetVenueId, isNull);
      expect(d.banquetVenueName, isNull);
      expect(d.banquetVenueCapacity, isNull);
      // The hall's address/pin must NOT survive as the "private" location —
      // the property screen would otherwise accept the old venue as the place.
      expect(d.location, isNull);
      expect(d.eventLatitude, isNull);
      expect(d.eventLongitude, isNull);
      expect(d.hasEventCoords, isFalse);
      expect(d.venueType, VenueType.privateProperty);
    });

    test('the old hall address never becomes the property address', () {
      ctrl().setVenueType(VenueType.banquetHall);
      ctrl().setBanquetVenue(
        venueId: 'v1',
        venueName: 'Grand Palace',
        address: 'Grand Palace, Gachibowli',
        latitude: 17.44,
        longitude: 78.35,
      );
      ctrl().setVenueType(VenueType.privateProperty);

      final p = container.read(eventDraftProvider).propertyDraft;
      expect(p, isNotNull);
      expect(p!.addressLine1, isNull);
      expect(p.cityPincode, isNull);
      expect(p.isComplete, isFalse); // needs a fresh, pinned location
    });

    test('a plain search location survives when NO hall was selected', () {
      ctrl().setEventLocation(
        address: 'Jubilee Hills, Hyderabad',
        latitude: 17.43,
        longitude: 78.40,
      );
      ctrl().setVenueType(VenueType.privateProperty);

      final d = container.read(eventDraftProvider);
      expect(d.location, 'Jubilee Hills, Hyderabad'); // the customer's own pick
      expect(d.eventLatitude, 17.43);
      expect(d.hasEventCoords, isTrue);
    });
  });

  group('start/end time consistency', () {
    test('first start pick auto-sets end to start + 3h', () {
      final start = DateTime(2026, 8, 20, 19, 0);
      ctrl().setStartTime(start);
      final d = container.read(eventDraftProvider);
      expect(d.startTime, start);
      expect(d.endTime, start.add(const Duration(hours: 3)));
    });

    test('changing start preserves the previous duration (no stale end)', () {
      ctrl().setStartTime(DateTime(2026, 8, 20, 19, 0));
      ctrl().setEndTime(DateTime(2026, 8, 20, 21, 0)); // 2h event
      // Re-pick a LATER start — previously the old 21:00 end survived,
      // leaving end before start.
      ctrl().setStartTime(DateTime(2026, 8, 20, 23, 0));
      final d = container.read(eventDraftProvider);
      expect(d.endTime!.isAfter(d.startTime!), isTrue);
      expect(d.endTime!.difference(d.startTime!), const Duration(hours: 2));
    });

    test('setEndTime rejects an end at/before start', () {
      ctrl().setStartTime(DateTime(2026, 8, 20, 19, 0));
      final endBefore = DateTime(2026, 8, 20, 18, 0);
      ctrl().setEndTime(endBefore);
      final d = container.read(eventDraftProvider);
      expect(d.endTime, isNot(endBefore));
      expect(d.endTime!.isAfter(d.startTime!), isTrue);
    });
  });

  group('date changes re-anchor times', () {
    test('times move to the new date, keeping wall-clock time', () {
      ctrl().setDate(DateTime(2026, 8, 20));
      ctrl().setStartTime(DateTime(2026, 8, 20, 19, 0));
      ctrl().setDate(DateTime(2026, 9, 5));
      final d = container.read(eventDraftProvider);
      expect(d.startTime, DateTime(2026, 9, 5, 19, 0));
      expect(d.endTime, DateTime(2026, 9, 5, 22, 0));
    });
  });

  group('banquet venue becomes the event location', () {
    test('selecting a venue sets its address + coordinates', () {
      // A previously-typed home location/coords should be replaced by the
      // venue's, so restaurants sort near the venue — not the old address.
      ctrl().setEventLocation(
        address: 'Home, Jubilee Hills',
        latitude: 17.43,
        longitude: 78.40,
      );
      ctrl().setBanquetVenue(
        venueId: 'v1',
        venueName: 'Grand Palace',
        address: 'Grand Palace, Gachibowli',
        latitude: 17.44,
        longitude: 78.35,
      );
      final d = container.read(eventDraftProvider);
      expect(d.banquetVenueId, 'v1');
      expect(d.banquetVenueName, 'Grand Palace');
      expect(d.location, 'Grand Palace, Gachibowli');
      expect(d.eventLatitude, 17.44);
      expect(d.eventLongitude, 78.35);
    });

    test('a venue without coordinates clears the stale pin', () {
      ctrl().setEventLocation(
        address: 'Home',
        latitude: 17.43,
        longitude: 78.40,
      );
      ctrl().setBanquetVenue(venueId: 'v2', venueName: 'Community Hall');
      final d = container.read(eventDraftProvider);
      expect(d.location, 'Community Hall'); // falls back to the name
      expect(d.eventLatitude, isNull);
      expect(d.eventLongitude, isNull);
    });
  });

  group('changing the event location invalidates dependent choices', () {
    // Fixed IST "now" so cascade assertions stay deterministic forever.
    final now = DateTime(2026, 8, 1, 12, 0);

    /// Fills the event-details fields so planningNextStep reaches the
    /// venue branch.
    void fillBasics() {
      ctrl().setEventName('Test Event');
      ctrl().setSession('Dinner');
      ctrl().setDate(DateTime(2026, 8, 20));
      ctrl().setStartTime(DateTime(2026, 8, 20, 19));
      ctrl().setTier(
        tierId: '00000000-0000-4000-8000-000000000111',
        tierCode: 'STANDARD',
      );
    }

    test('banquet venue is cleared — the hall must be picked again', () {
      fillBasics();
      ctrl().setVenueType(VenueType.banquetHall);
      ctrl().setBanquetVenue(
        venueId: 'v1',
        venueName: 'Grand Palace',
        address: 'Grand Palace, Gachibowli',
        latitude: 17.44,
        longitude: 78.35,
      );
      // Customer explicitly moves the event across town.
      ctrl().setEventLocation(
        address: 'New Farmhouse, Shamirpet',
        latitude: 17.60,
        longitude: 78.57,
      );
      final d = container.read(eventDraftProvider);
      expect(d.banquetVenueId, isNull);
      expect(d.banquetVenueName, isNull);
      expect(d.location, 'New Farmhouse, Shamirpet');
      expect(d.eventLatitude, 17.60);
      // Planning flow demands the venue step again — no stale routing.
      expect(planningNextStep(d, now: now).route, AppRoutes.eventVenueType);
    });

    test('property address details are cleared, the TYPE survives', () {
      fillBasics();
      ctrl().setEventLocation(
        address: 'Old Villa, Jubilee Hills',
        latitude: 17.43,
        longitude: 78.40,
      );
      ctrl().setVenueType(VenueType.privateProperty);
      ctrl().setPropertyType(PropertyType.farmhouse);
      ctrl().setPropertyAddress(
        line1: '12 Old Villa',
        landmark: 'Behind the lake',
        cityPincode: 'Hyderabad 500033',
      );
      expect(
          container.read(eventDraftProvider).propertyDraft!.isComplete, isTrue);
      // Move the event — the old address details described the old place.
      ctrl().setEventLocation(
        address: 'New Farmhouse, Shamirpet',
        latitude: 17.60,
        longitude: 78.57,
      );
      final d = container.read(eventDraftProvider);
      expect(d.propertyDraft!.type, PropertyType.farmhouse); // survives
      expect(d.propertyDraft!.addressLine1, isNull);
      expect(d.propertyDraft!.landmark, isNull);
      expect(d.propertyDraft!.cityPincode, isNull);
      expect(d.propertyDraft!.isComplete, isFalse);
      // Planning flow demands property completion again.
      expect(planningNextStep(d, now: now).route, AppRoutes.eventProperty);
    });

    test('initial prefill is unaffected (nothing to invalidate yet)', () {
      ctrl().setEventLocation(
        address: 'Home, Delhi',
        latitude: 28.61,
        longitude: 77.21,
      );
      final d = container.read(eventDraftProvider);
      expect(d.location, 'Home, Delhi');
      expect(d.banquetVenueId, isNull);
      expect(d.propertyDraft, isNull);
    });
  });

  group('pinVenueCoords (late background geocode)', () {
    test('pins coords for the still-selected venue', () {
      ctrl().setBanquetVenue(venueId: 'v1', venueName: 'Grand Palace');
      ctrl().pinVenueCoords(venueId: 'v1', latitude: 17.44, longitude: 78.35);
      final d = container.read(eventDraftProvider);
      expect(d.eventLatitude, 17.44);
      expect(d.eventLongitude, 78.35);
    });

    test('ignored when the user switched venue meanwhile', () {
      ctrl().setBanquetVenue(venueId: 'v1', venueName: 'Grand Palace');
      ctrl().setBanquetVenue(venueId: 'v2', venueName: 'Community Hall');
      // Slow lookup for v1 lands late — must not stamp v1's point onto v2.
      ctrl().pinVenueCoords(venueId: 'v1', latitude: 17.44, longitude: 78.35);
      final d = container.read(eventDraftProvider);
      expect(d.eventLatitude, isNull);
      expect(d.eventLongitude, isNull);
    });

    test('ignored when coordinates already exist', () {
      ctrl().setBanquetVenue(
        venueId: 'v1',
        venueName: 'Grand Palace',
        address: 'Grand Palace, Gachibowli',
        latitude: 17.44,
        longitude: 78.35,
      );
      ctrl().pinVenueCoords(venueId: 'v1', latitude: 1.0, longitude: 2.0);
      final d = container.read(eventDraftProvider);
      expect(d.eventLatitude, 17.44);
      expect(d.eventLongitude, 78.35);
    });
  });

  group('event location coordinates', () {
    test('a new address without coords CLEARS the previous pin', () {
      ctrl().setEventLocation(
        address: 'Venue A',
        latitude: 17.4,
        longitude: 78.4,
      );
      ctrl().setEventLocation(address: 'Venue B');
      final d = container.read(eventDraftProvider);
      expect(d.location, 'Venue B');
      expect(d.eventLatitude, isNull);
      expect(d.eventLongitude, isNull);
    });

    test('coords are stored when provided', () {
      ctrl().setEventLocation(
        address: 'Venue A',
        latitude: 17.4,
        longitude: 78.4,
      );
      final d = container.read(eventDraftProvider);
      expect(d.eventLatitude, 17.4);
      expect(d.eventLongitude, 78.4);
    });
  });

  // The exact regression the reviewer flagged: a banquet venue picked for a
  // small party, then a later guest-count bump beyond its capacity — done via
  // the REAL controller + REAL shared cascade (no provider override), because
  // selectedBanquetVenueCheckProvider only runs while VenueTypeScreen is
  // mounted and would be bypassed entirely if the cascade treated the stale
  // venue as complete.
  group('banquet capacity vs. a later guest-count change (end-to-end)', () {
    final now = DateTime(2026, 8, 1, 12, 0); // fixed IST business clock

    void fillBasics() {
      ctrl().setEventName('Reception');
      ctrl().setSession('Dinner');
      ctrl().setDate(DateTime(2026, 8, 20));
      ctrl().setStartTime(DateTime(2026, 8, 20, 19));
      ctrl().setEventLocation(
        address: 'Grand Palace, Gachibowli',
        latitude: 17.44,
        longitude: 78.35,
      );
      ctrl().setTier(
        tierId: '00000000-0000-4000-8000-000000000111',
        tierCode: 'STANDARD',
      );
    }

    void pickVenue({
      required String id,
      required String name,
      int? capacity,
    }) {
      ctrl().setVenueType(VenueType.banquetHall);
      ctrl().setBanquetVenue(
        venueId: id,
        venueName: name,
        address: '$name address',
        latitude: 17.44,
        longitude: 78.35,
        capacity: capacity,
      );
    }

    test(
        'venue fits at 50; raising guests past capacity re-opens the venue '
        'step for BOTH planning nav and checkout', () {
      fillBasics();
      ctrl().setGuestCount(50);
      pickVenue(id: 'v1', name: 'Grand Palace', capacity: 200);

      // Step 1: complete → planning routes to browse, checkout is open.
      var d = container.read(eventDraftProvider);
      expect(d.banquetVenueCapacity, 200);
      expect(planningNextStep(d, now: now).route, AppRoutes.userHome);
      expect(checkoutPlanningGap(d, now: now), isNull);

      // Step 2–4: back on Event Details, bump guests beyond the hall.
      ctrl().setGuestCount(300);
      d = container.read(eventDraftProvider);
      // The venue id is STILL present — the old behaviour would treat the
      // venue step as done and skip VenueTypeScreen. The shared cascade now
      // re-opens it instead, so Home/Event Details AND checkout all agree.
      expect(d.banquetVenueId, 'v1');
      final planning = planningNextStep(d, now: now);
      expect(planning.route, AppRoutes.eventVenueType);
      expect(planning.hint, contains('no longer fits'));
      expect(checkoutPlanningGap(d, now: now)!.route, AppRoutes.eventVenueType);
    });

    test('dropping guests back within capacity restores completion', () {
      fillBasics();
      ctrl().setGuestCount(50);
      pickVenue(id: 'v1', name: 'Grand Palace', capacity: 200);
      ctrl().setGuestCount(300);
      expect(
        planningNextStep(container.read(eventDraftProvider), now: now).route,
        AppRoutes.eventVenueType,
      );
      ctrl().setGuestCount(180); // back within 200
      expect(
        planningNextStep(container.read(eventDraftProvider), now: now).route,
        AppRoutes.userHome,
      );
    });

    test('picking a larger venue clears the block and stores its capacity', () {
      fillBasics();
      ctrl().setGuestCount(300);
      pickVenue(id: 'v1', name: 'Small Hall', capacity: 200);
      expect(
        planningNextStep(container.read(eventDraftProvider), now: now).route,
        AppRoutes.eventVenueType,
      );
      pickVenue(id: 'v2', name: 'Big Hall', capacity: 800);
      final d = container.read(eventDraftProvider);
      expect(d.banquetVenueId, 'v2');
      expect(d.banquetVenueCapacity, 800);
      expect(planningNextStep(d, now: now).route, AppRoutes.userHome);
    });

    test('a venue with unknown capacity is never blocked by guest count', () {
      fillBasics();
      ctrl().setGuestCount(4000);
      pickVenue(id: 'v1', name: 'Unknown-cap Hall'); // capacity null
      final d = container.read(eventDraftProvider);
      expect(d.banquetVenueCapacity, isNull);
      expect(planningNextStep(d, now: now).route, AppRoutes.userHome);
    });

    test('moving the event location clears the captured capacity too', () {
      fillBasics();
      ctrl().setGuestCount(50);
      pickVenue(id: 'v1', name: 'Grand Palace', capacity: 200);
      ctrl().setEventLocation(
        address: 'New Farmhouse, Shamirpet',
        latitude: 17.60,
        longitude: 78.57,
      );
      final d = container.read(eventDraftProvider);
      expect(d.banquetVenueId, isNull);
      expect(d.banquetVenueCapacity, isNull);
    });

    test('switching to private property clears the captured capacity', () {
      fillBasics();
      ctrl().setGuestCount(50);
      pickVenue(id: 'v1', name: 'Grand Palace', capacity: 200);
      ctrl().setVenueType(VenueType.privateProperty);
      expect(container.read(eventDraftProvider).banquetVenueCapacity, isNull);
    });

    test(
        'clearing then re-entering the event name preserves the venue id, name '
        'AND capacity — the guard still fires afterwards', () {
      fillBasics(); // name = 'Reception'
      ctrl().setGuestCount(50);
      pickVenue(id: 'v1', name: 'Grand Palace', capacity: 200);

      // Clear the name (home card falls back to a composed title) — an edit
      // with NOTHING to do with the venue. The manual rebuild in setEventName
      // must carry every unrelated field, capacity included.
      ctrl().setEventName('');
      var d = container.read(eventDraftProvider);
      expect(d.eventName, isNull);
      expect(d.banquetVenueId, 'v1');
      expect(d.banquetVenueName, 'Grand Palace');
      expect(d.banquetVenueCapacity, 200); // regression: survives the clear

      // Re-enter a name.
      ctrl().setEventName('Sangeet Night');
      d = container.read(eventDraftProvider);
      expect(d.eventName, 'Sangeet Night');
      expect(d.banquetVenueCapacity, 200); // still captured

      // End-to-end: the guard still fires once guests outgrow the hall.
      ctrl().setGuestCount(300);
      d = container.read(eventDraftProvider);
      expect(planningNextStep(d, now: now).route, AppRoutes.eventVenueType);
      expect(checkoutPlanningGap(d, now: now)!.route, AppRoutes.eventVenueType);
    });
  });
}
