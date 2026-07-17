import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/core/utils/geo.dart';
import 'package:banquet_catering_app/data/models/restaurant.dart';

Restaurant _r({double? lat, double? lng, double? distanceKm}) => Restaurant(
      id: 'r1',
      name: 'Test Kitchen',
      latitude: lat,
      longitude: lng,
      distanceKm: distanceKm,
    );

void main() {
  group('haversineKm', () {
    test('is zero for identical points', () {
      expect(haversineKm(lat1: 17.4, lng1: 78.4, lat2: 17.4, lng2: 78.4),
          closeTo(0, 0.001));
    });

    test('matches a known long-distance pair (Hyderabad→Delhi ≈ 1252 km)', () {
      final d = haversineKm(lat1: 17.4, lng1: 78.45, lat2: 28.61, lng2: 77.21)!;
      expect(d, closeTo(1252, 15));
    });

    test('returns null when any coordinate is missing', () {
      expect(haversineKm(lat1: 1, lng1: 2, lat2: null, lng2: 4), isNull);
      expect(haversineKm(lat1: null, lng1: 2, lat2: 3, lng2: 4), isNull);
    });
  });

  group('distanceToRestaurantKm', () {
    test('prefers the server-computed distanceKm over haversine', () {
      // Coords say ~0 km away, but the RPC distance says 7.5 — trust the RPC.
      final d = distanceToRestaurantKm(
        _r(lat: 10, lng: 10, distanceKm: 7.5),
        customerLat: 10,
        customerLng: 10,
      );
      expect(d, 7.5);
    });

    test('falls back to haversine when no distanceKm is present', () {
      final d = distanceToRestaurantKm(
        _r(lat: 17.5, lng: 78.5),
        customerLat: 17.4,
        customerLng: 78.45,
      );
      expect(d, isNotNull);
      expect(d!, closeTo(12, 4)); // ~12 km apart
    });

    test('is null when neither side has usable coordinates', () {
      expect(
        distanceToRestaurantKm(_r(), customerLat: null, customerLng: null),
        isNull,
      );
      expect(
        distanceToRestaurantKm(_r(lat: 1, lng: 1),
            customerLat: null, customerLng: null),
        isNull,
      );
    });
  });

  group('serviceabilityOf', () {
    test('inRange within the service radius', () {
      expect(
        serviceabilityOf(_r(distanceKm: 3), customerLat: 1, customerLng: 1),
        Serviceability.inRange,
      );
    });

    test('inRange exactly at the radius boundary', () {
      expect(
        serviceabilityOf(_r(distanceKm: kServiceRadiusKm),
            customerLat: 1, customerLng: 1),
        Serviceability.inRange,
      );
    });

    test('outOfRange just beyond the radius', () {
      expect(
        serviceabilityOf(_r(distanceKm: kServiceRadiusKm + 0.1),
            customerLat: 1, customerLng: 1),
        Serviceability.outOfRange,
      );
    });

    test('unknown when distance cannot be computed (no customer location)', () {
      expect(
        serviceabilityOf(_r(lat: 1, lng: 1),
            customerLat: null, customerLng: null),
        Serviceability.unknown,
      );
    });
  });
}
