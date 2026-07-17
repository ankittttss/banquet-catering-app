import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/data/models/restaurant.dart';

void main() {
  group('RestaurantStatus.fromDb', () {
    test('maps each known db value', () {
      expect(RestaurantStatus.fromDb('draft'), RestaurantStatus.draft);
      expect(RestaurantStatus.fromDb('published'), RestaurantStatus.published);
      expect(RestaurantStatus.fromDb('suspended'), RestaurantStatus.suspended);
      expect(RestaurantStatus.fromDb('archived'), RestaurantStatus.archived);
    });

    test('defaults unknown/null to published (legacy geo-RPC rows)', () {
      expect(RestaurantStatus.fromDb(null), RestaurantStatus.published);
      expect(RestaurantStatus.fromDb('weird'), RestaurantStatus.published);
    });
  });

  group('Restaurant.fromMap status + is_active', () {
    test('reads status and coords, defaults status when absent', () {
      final r = Restaurant.fromMap({
        'id': 'r1',
        'name': 'Kitchen',
        'status': 'suspended',
        'is_active': false,
        'latitude': 17.4,
        'longitude': 78.4,
      });
      expect(r.status, RestaurantStatus.suspended);
      expect(r.isActive, isFalse);
      expect(r.latitude, 17.4);
    });

    test('a row with no status column is treated as published', () {
      final r = Restaurant.fromMap({'id': 'r2', 'name': 'Legacy'});
      expect(r.status, RestaurantStatus.published);
    });
  });

  test('labels are human-facing', () {
    expect(RestaurantStatus.published.label, 'Live');
    expect(RestaurantStatus.draft.label, 'Draft');
  });
}
