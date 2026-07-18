import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
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
}
