import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/collection.dart';
import '../../data/models/event_category.dart';
import '../../data/models/restaurant.dart';
import 'menu_providers.dart';
import 'repositories_providers.dart';

/// The 8-tile "What's the occasion?" grid on home.
final eventCategoriesProvider =
    FutureProvider<List<EventCategory>>((ref) async {
  return ref.read(taxonomyRepositoryProvider).fetchEventCategories();
});

/// Curated horizontal-scroll tiles under the event grid.
final collectionsProvider = FutureProvider<List<Collection>>((ref) async {
  return ref.read(taxonomyRepositoryProvider).fetchCollections();
});

/// Popular restaurants — re-exports the unfiltered list. When we add a
/// `popularity_score` column, the Supabase repo already sorts by it.
final popularRestaurantsProvider =
    Provider<AsyncValue<List<Restaurant>>>((ref) {
  return ref.watch(restaurantsProvider);
});

/// Sticky search-bar query (unused today; wired up by the search screen).
final homeSearchProvider = StateProvider<String>((ref) => '');

/// Home sort / filter chip selection — matches prototype's chip row.
enum HomeSort { relevance, rating, fastest, veg, offers, budget }

final homeSortProvider =
    StateProvider<HomeSort>((ref) => HomeSort.relevance);

extension HomeSortLabel on HomeSort {
  String get label => switch (this) {
        HomeSort.relevance => 'Relevance',
        HomeSort.rating => 'Rating 4.0+',
        HomeSort.fastest => 'Fastest',
        HomeSort.veg => 'Pure Veg',
        HomeSort.offers => 'Offers',
        HomeSort.budget => 'Budget',
      };
}

/// Filtered + sorted list that drives the restaurant cards on home.
final homeRestaurantsProvider =
    Provider<AsyncValue<List<Restaurant>>>((ref) {
  final base = ref.watch(restaurantsProvider);
  final sort = ref.watch(homeSortProvider);

  return base.whenData((list) {
    Iterable<Restaurant> result = list;
    switch (sort) {
      case HomeSort.rating:
        result = result.where((r) => (r.rating ?? 0) >= 4.0);
        result = result.toList()
          ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      case HomeSort.fastest:
        result = result.toList()
          ..sort((a, b) => (a.deliveryMinMinutes ?? 999)
              .compareTo(b.deliveryMinMinutes ?? 999));
        break;
      case HomeSort.veg:
        result = result.where((r) => r.isPureVeg);
        break;
      case HomeSort.budget:
        result = result.toList()
          ..sort((a, b) => (a.pricePerPlate ?? 9999)
              .compareTo(b.pricePerPlate ?? 9999));
        break;
      case HomeSort.offers:
      case HomeSort.relevance:
        result = result.toList()
          ..sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
        break;
    }
    return result.toList(growable: false);
  });
});

/// Kept for back-compat with existing code paths (restaurant detail,
/// event-type picker, etc.). Maps event categories into the legacy shape.
class EventType {
  const EventType({
    required this.id,
    required this.label,
    required this.defaultGuestCount,
    required this.defaultSession,
  });
  final String id;
  final String label;
  final int defaultGuestCount;
  final String defaultSession;
}

final eventTypesProvider = Provider<List<EventType>>((ref) {
  final cats = ref.watch(eventCategoriesProvider).valueOrNull ?? const [];
  return cats
      .map((c) => EventType(
            id: c.slug,
            label: c.name,
            defaultGuestCount: c.defaultGuestCount,
            defaultSession: c.defaultSession,
          ))
      .toList(growable: false);
});

final selectedEventTypeProvider = StateProvider<String?>((ref) => null);
