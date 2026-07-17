import '../../core/utils/geo.dart';
import '../models/event_tier.dart';
import '../models/restaurant.dart';

/// Contract for loading event tiers and tier-scoped restaurant lists.
abstract interface class EventTierRepository {
  Future<List<EventTier>> fetchTiers();

  /// Restaurants whose per-guest price band overlaps the given tier's band.
  /// When [latitude] / [longitude] are provided, results are also filtered
  /// to within [radiusKm] and ordered by distance.
  ///
  /// The default radius matches [kServiceRadiusKm] — the same limit the
  /// checkout serviceability guard enforces. (It used to be 25 km, which
  /// showed customers kitchens they'd be blocked from ordering at.)
  Future<List<Restaurant>> restaurantsForTier({
    required String tierId,
    double? latitude,
    double? longitude,
    double radiusKm = kServiceRadiusKm,
  });
}
