import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
