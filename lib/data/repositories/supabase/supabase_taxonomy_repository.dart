import '../../../core/supabase/supabase_client.dart';
import '../../models/collection.dart';
import '../../models/event_category.dart';
import '../../models/restaurant_offer.dart';
import '../../models/trending_search.dart';
import '../taxonomy_repository.dart';

class SupabaseTaxonomyRepository implements TaxonomyRepository {
  @override
  Future<List<EventCategory>> fetchEventCategories() async {
    final rows = await supabase
        .from('event_categories')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows
        .map<EventCategory>(EventCategory.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<Collection>> fetchCollections() async {
    final rows = await supabase
        .from('collections')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows.map<Collection>(Collection.fromMap).toList(growable: false);
  }

  @override
  Future<List<RestaurantOffer>> fetchOffersFor(String restaurantId) async {
    final rows = await supabase
        .from('restaurant_offers')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows
        .map<RestaurantOffer>(RestaurantOffer.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<TrendingSearch>> fetchTrendingSearches() async {
    final rows = await supabase
        .from('trending_searches')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows
        .map<TrendingSearch>(TrendingSearch.fromMap)
        .toList(growable: false);
  }
}
