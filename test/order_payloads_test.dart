import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/data/models/cart_item.dart';
import 'package:banquet_catering_app/data/models/event_draft.dart';
import 'package:banquet_catering_app/data/models/menu_item.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/data/repositories/order_payloads.dart';

void main() {
  group('orderEventPayload — full booking persistence', () {
    final draft = EventDraft(
      eventName: "Aanya's Sangeet",
      categorySlug: 'wedding',
      date: DateTime(2026, 8, 20),
      location: 'Banjara Hills, Hyderabad',
      eventLatitude: 17.41,
      eventLongitude: 78.44,
      session: 'Dinner',
      startTime: DateTime(2026, 8, 20, 19, 0),
      endTime: DateTime(2026, 8, 20, 22, 30),
      guestCount: 150,
      tierId: 'tier-1',
      banquetVenueId: 'venue-1',
      venueType: VenueType.privateProperty,
      propertyDraft: const PrivatePropertyDraft(
        type: PropertyType.farmhouse,
        addressLine1: '12 Farm Rd',
        cityPincode: 'Hyderabad 500001',
      ),
      addonQuantities: const {'round_dining_table': 5},
    );

    test('persists every planning field (previously dropped)', () {
      final p = orderEventPayload(draft);
      expect(p['name'], "Aanya's Sangeet");
      expect(p['event_date'], '2026-08-20');
      expect(p['location'], 'Banjara Hills, Hyderabad');
      expect(p['session'], 'Dinner');
      expect(p['start_time'], '19:00');
      expect(p['end_time'], '22:30');
      expect(p['guest_count'], 150);
      expect(p['tier_id'], 'tier-1');
      expect(p['banquet_venue_id'], 'venue-1');
      // The fields that used to vanish:
      expect(p['category_slug'], 'wedding');
      expect(p['venue_type'], 'private_property');
      expect(p['event_latitude'], 17.41);
      expect(p['event_longitude'], 78.44);
      expect(p['property_details'], isA<Map<String, dynamic>>());
      expect(p['addon_selections'], {'round_dining_table': 5});
    });

    test('omits optional keys when absent', () {
      final minimal = EventDraft(
        date: DateTime(2026, 8, 20),
        location: 'X',
        session: 'Lunch',
        startTime: DateTime(2026, 8, 20, 12, 0),
        endTime: DateTime(2026, 8, 20, 15, 0),
        guestCount: 50,
      );
      final p = orderEventPayload(minimal);
      expect(p.containsKey('name'), isFalse);
      expect(p.containsKey('category_slug'), isFalse);
      expect(p.containsKey('venue_type'), isFalse);
      expect(p.containsKey('event_latitude'), isFalse);
      expect(p.containsKey('property_details'), isFalse);
      expect(p.containsKey('addon_selections'), isFalse);
    });
  });

  group('orderItemsPayload — menu customizations', () {
    test('carries portion, multiplier, spice and notes per line', () {
      final cart = [
        CartItem(
          item: const MenuItem(
            id: 'i1',
            restaurantId: 'r1',
            categoryId: 'c1',
            name: 'Paneer Tikka',
            price: 220,
          ),
          qty: 2,
          portion: Portion.large,
          spice: SpiceLevel.spicy,
          notes: 'less oil',
        ),
      ];
      final items = orderItemsPayload(cart);
      expect(items, hasLength(1));
      expect(items.first['menu_item_id'], 'i1');
      expect(items.first['qty_per_guest'], 2);
      expect(items.first['portion_multiplier'], Portion.large.multiplier);
      expect(items.first['portion'], 'large');
      expect(items.first['spice'], 'spicy');
      expect(items.first['notes'], 'less oil');
    });

    test('omits empty notes', () {
      final items = orderItemsPayload([
        CartItem(
          item: const MenuItem(
            id: 'i2',
            restaurantId: 'r1',
            categoryId: 'c1',
            name: 'Dal',
            price: 180,
          ),
        ),
      ]);
      expect(items.first.containsKey('notes'), isFalse);
      expect(items.first['portion'], 'regular');
      expect(items.first['portion_multiplier'], 1.0);
    });
  });
}
