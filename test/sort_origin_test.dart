import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/core/utils/geo.dart';
import 'package:banquet_catering_app/data/models/event_draft.dart';
import 'package:banquet_catering_app/data/models/user_address.dart';

void main() {
  const home = UserAddress(
    id: 'a1',
    userId: 'u1',
    label: AddressLabel.home,
    fullAddress: '12 Rose Villa, Jubilee Hills',
    latitude: 17.43,
    longitude: 78.40,
  );

  group('resolveSortOrigin', () {
    test('event coordinates win over the saved address', () {
      final origin = resolveSortOrigin(
        draft: const EventDraft(
          location: 'Grand Palace, Gachibowli',
          eventLatitude: 17.44,
          eventLongitude: 78.35,
        ),
        savedAddress: home,
      );
      expect(origin.lat, 17.44);
      expect(origin.lng, 78.35);
    });

    test('planning WITHOUT coords never falls back to home (the bug)', () {
      // Header says "Event location" — sorting around home would lie.
      final origin = resolveSortOrigin(
        draft: const EventDraft(location: 'Community Hall'),
        savedAddress: home,
      );
      expect(origin.lat, isNull);
      expect(origin.lng, isNull);
    });

    test('not planning → saved address coordinates', () {
      final origin = resolveSortOrigin(
        draft: const EventDraft(),
        savedAddress: home,
      );
      expect(origin.lat, 17.43);
      expect(origin.lng, 78.40);
    });

    test('whitespace-only event location does not count as planning', () {
      final origin = resolveSortOrigin(
        draft: const EventDraft(location: '   '),
        savedAddress: home,
      );
      expect(origin.lat, 17.43);
      expect(origin.lng, 78.40);
    });

    test('nothing anywhere → null (popularity sort)', () {
      final origin = resolveSortOrigin(
        draft: const EventDraft(),
        savedAddress: null,
      );
      expect(origin.lat, isNull);
      expect(origin.lng, isNull);
    });

    test('saved address without coords is not used', () {
      const noCoords = UserAddress(
        id: 'a2',
        userId: 'u1',
        label: AddressLabel.work,
        fullAddress: 'Office, Hitec City',
      );
      final origin = resolveSortOrigin(
        draft: const EventDraft(),
        savedAddress: noCoords,
      );
      expect(origin.lat, isNull);
      expect(origin.lng, isNull);
    });
  });
}
