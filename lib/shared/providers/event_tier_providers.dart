import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/event_tier.dart';
import '../../data/models/restaurant.dart';
import 'repositories_providers.dart';

/// All active event tiers, sorted by price band (low → high).
/// Falls back to the built-in list when the repository errors so the
/// event-creation screen never blocks on a backend outage.
final eventTiersProvider = FutureProvider<List<EventTier>>((ref) async {
  final repo = ref.watch(eventTierRepositoryProvider);
  try {
    final tiers = await repo.fetchTiers();
    if (tiers.isEmpty) return List.of(fallbackEventTiers);
    return tiers;
  } catch (_) {
    return List.of(fallbackEventTiers);
  }
});

/// Args bundle for [restaurantsForTierProvider] so a single cached provider
/// covers every (tier, location, radius) combination.
class RestaurantsForTierArgs {
  const RestaurantsForTierArgs({
    required this.tierId,
    this.latitude,
    this.longitude,
    this.radiusKm = 25,
  });

  final String tierId;
  final double? latitude;
  final double? longitude;
  final double radiusKm;

  @override
  bool operator ==(Object other) =>
      other is RestaurantsForTierArgs &&
      other.tierId == tierId &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.radiusKm == radiusKm;

  @override
  int get hashCode => Object.hash(tierId, latitude, longitude, radiusKm);
}

/// Restaurants whose per-guest price band overlaps the chosen tier.
final restaurantsForTierProvider = FutureProvider.family<
    List<Restaurant>, RestaurantsForTierArgs>((ref, args) async {
  final repo = ref.watch(eventTierRepositoryProvider);
  return repo.restaurantsForTier(
    tierId: args.tierId,
    latitude: args.latitude,
    longitude: args.longitude,
    radiusKm: args.radiusKm,
  );
});
