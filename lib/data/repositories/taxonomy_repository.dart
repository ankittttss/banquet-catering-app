import '../models/collection.dart';
import '../models/event_category.dart';
import '../models/restaurant_offer.dart';
import '../models/trending_search.dart';

/// Home-screen taxonomy — event categories, curated collections, per-restaurant
/// offers and the trending-searches chip row. Small, cacheable, rarely changes.
/// Admin-managed via RLS.
abstract interface class TaxonomyRepository {
  Future<List<EventCategory>> fetchEventCategories();
  Future<List<Collection>> fetchCollections();
  Future<List<RestaurantOffer>> fetchOffersFor(String restaurantId);
  Future<List<TrendingSearch>> fetchTrendingSearches();
}
