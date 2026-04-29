import '../../../core/supabase/supabase_client.dart';
import '../../models/event_tier.dart';
import '../../models/restaurant.dart';
import '../event_tier_repository.dart';

class SupabaseEventTierRepository implements EventTierRepository {
  @override
  Future<List<EventTier>> fetchTiers() async {
    final rows = await supabase
        .from('event_tiers')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows
        .map<EventTier>(EventTier.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<Restaurant>> restaurantsForTier({
    required String tierId,
    double? latitude,
    double? longitude,
    double radiusKm = 25,
  }) async {
    final rows = await supabase.rpc<dynamic>(
      'restaurants_for_event',
      params: {
        'p_tier_id': tierId,
        'p_lat': latitude,
        'p_lng': longitude,
        'p_radius_km': radiusKm,
      },
    );
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map<Restaurant>(Restaurant.fromMap)
        .toList(growable: false);
  }
}
