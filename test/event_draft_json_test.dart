import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/data/models/event_draft.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';

/// Persistence contract for the banquet fields — the captured venue capacity
/// must survive a shared_preferences round-trip so a restored draft still
/// guards the guest-count check, and a legacy payload written before the field
/// existed must decode safely to null (not throw, not resurrect a stale value).
void main() {
  group('EventDraft toJson → fromJson round-trip', () {
    test('banquetVenueCapacity survives a full round-trip', () {
      const original = EventDraft(
        eventName: 'Reception',
        session: 'Dinner',
        guestCount: 120,
        tierId: '00000000-0000-4000-8000-000000000111',
        tierCode: 'STANDARD',
        venueType: VenueType.banquetHall,
        banquetVenueId: 'v1',
        banquetVenueName: 'Grand Palace',
        banquetVenueCapacity: 200,
      );
      final restored = EventDraft.fromJson(original.toJson());
      expect(restored.banquetVenueId, 'v1');
      expect(restored.banquetVenueName, 'Grand Palace');
      expect(restored.banquetVenueCapacity, 200);
      expect(restored.guestCount, 120);
      expect(restored.venueType, VenueType.banquetHall);
    });

    test('a null capacity is omitted from JSON and round-trips back to null',
        () {
      const original = EventDraft(
        venueType: VenueType.banquetHall,
        banquetVenueId: 'v1',
        banquetVenueName: 'Unknown-cap Hall',
      );
      final json = original.toJson();
      expect(json.containsKey('banquetVenueCapacity'), isFalse);
      expect(EventDraft.fromJson(json).banquetVenueCapacity, isNull);
    });
  });

  test(
      'legacy persisted draft WITHOUT banquetVenueCapacity decodes to null '
      '(venue still restored, no crash)', () {
    // A v:1 payload written before the field existed: venue present, capacity
    // key entirely absent.
    final legacy = <String, dynamic>{
      'v': 1,
      'eventName': 'Old Reception',
      'session': 'Dinner',
      'guestCount': 80,
      'tierId': '00000000-0000-4000-8000-000000000111',
      'tierCode': 'STANDARD',
      'venueType': VenueType.banquetHall.dbValue,
      'banquetVenueId': 'v1',
      'banquetVenueName': 'Grand Palace',
    };
    final restored = EventDraft.fromJson(legacy);
    expect(restored.banquetVenueId, 'v1'); // venue still restored
    expect(restored.banquetVenueName, 'Grand Palace');
    expect(restored.banquetVenueCapacity, isNull); // safely absent
  });
}
