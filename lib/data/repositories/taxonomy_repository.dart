import '../models/collection.dart';
import '../models/event_category.dart';
import '../models/trending_search.dart';

/// Home-screen taxonomy — event categories, curated collections and the
/// trending-searches chip row. Small, cacheable, rarely changes.
/// Admin-managed via RLS.
abstract interface class TaxonomyRepository {
  Future<List<EventCategory>> fetchEventCategories();
  Future<List<Collection>> fetchCollections();

  // NOTE: all customer-facing offers logic (fetchOffersFor,
  // fetchOfferRestaurantIds) was removed with the MVP's Offers UI;
  // the restaurant_offers table stays in the database for a future offers
  // product.

  Future<List<TrendingSearch>> fetchTrendingSearches();
}
