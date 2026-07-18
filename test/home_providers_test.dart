import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:banquet_catering_app/data/models/event_draft.dart';
import 'package:banquet_catering_app/data/models/restaurant.dart';
import 'package:banquet_catering_app/shared/providers/event_providers.dart';
import 'package:banquet_catering_app/shared/providers/home_providers.dart';
import 'package:banquet_catering_app/shared/providers/menu_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('homeRestaurantsTitle — three honest states', () {
    test('not planning → Restaurants nearby', () {
      expect(homeRestaurantsTitle(const EventDraft()), 'Restaurants nearby');
    });

    test('planning + coordinates → serving your event location', () {
      expect(
        homeRestaurantsTitle(const EventDraft(
          location: 'Grand Palace',
          eventLatitude: 17.4,
          eventLongitude: 78.4,
        )),
        'Restaurants serving your event location',
      );
    });

    test('planning WITHOUT coordinates → neutral Popular restaurants', () {
      expect(
        homeRestaurantsTitle(const EventDraft(location: 'Community Hall')),
        'Popular restaurants',
      );
    });
  });

  group('Offers removal', () {
    test('HomeSort no longer contains an Offers chip', () {
      expect(
        HomeSort.values.map((s) => s.label),
        isNot(contains('Offers')),
      );
    });
  });

  group('collectionSearchTerm — catalog-verified card queries', () {
    test('all four live collections map to verified terms', () {
      expect(collectionSearchTerm('platters'), 'platter');
      expect(collectionSearchTerm('biryani'), 'biryani');
      expect(collectionSearchTerm('sweets'), 'sweet');
      expect(collectionSearchTerm('live'), 'live');
    });

    test('unknown slugs return null → their cards are hidden', () {
      expect(collectionSearchTerm('mystery-collection'), isNull);
    });
  });

  group('homeRestaurantsProvider ordering', () {
    final byDistance = [
      const Restaurant(id: 'near', name: 'Near', popularityScore: 1),
      const Restaurant(id: 'far', name: 'Far', popularityScore: 9),
    ];

    ProviderContainer make() {
      SharedPreferences.setMockInitialValues({});
      return ProviderContainer(
        overrides: [
          restaurantsProvider.overrideWith((_) async => byDistance),
        ],
      );
    }

    test('planning with coords keeps the nearest-first server order', () async {
      final c = make();
      addTearDown(c.dispose);
      c.read(eventDraftProvider.notifier).setEventLocation(
            address: 'Grand Palace',
            latitude: 17.4,
            longitude: 78.4,
          );
      await c.read(restaurantsProvider.future);
      final list = c.read(homeRestaurantsProvider).value!;
      expect(list.map((r) => r.id), ['near', 'far']); // NOT re-sorted
    });

    test('not planning → popularity ranking', () async {
      final c = make();
      addTearDown(c.dispose);
      await c.read(restaurantsProvider.future);
      final list = c.read(homeRestaurantsProvider).value!;
      expect(list.map((r) => r.id), ['far', 'near']); // popularity desc
    });
  });
}
