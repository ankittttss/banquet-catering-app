import '../models/event_tier.dart';
import '../models/restaurant.dart';

/// Contract for loading event tiers and tier-scoped restaurant lists.
abstract interface class EventTierRepository {
  Future<List<EventTier>> fetchTiers();

  /// Restaurants whose per-guest price band overlaps the given tier's band.
  /// When [latitude] / [longitude] are provided, results are also filtered
  /// to within [radiusKm] and ordered by distance.
  Future<List<Restaurant>> restaurantsForTier({
    required String tierId,
    double? latitude,
    double? longitude,
    double radiusKm = 25,
  });
}
