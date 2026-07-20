import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/event_tier.dart';
import '../../data/models/restaurant.dart';
import 'repositories_providers.dart';

/// All active event tiers, sorted by price band (low → high).
///
/// NO error fallback here: stub-vs-Supabase selection already happens in
/// repositories_providers, and the STUB repo returns the built-in fallback
/// tiers for offline dev. A real Supabase error surfaces as AsyncError so
/// the tier picker can show an honest Retry — silently substituting the
/// fallback list used to poison drafts with non-UUID tier ids ('budget')
/// that the live RPCs and place_order reject.
final eventTiersProvider = FutureProvider<List<EventTier>>((ref) async {
  final repo = ref.watch(eventTierRepositoryProvider);
  return repo.fetchTiers();
});

/// The draft's selected tier resolved against the CURRENTLY ACTIVE list, or
/// null when the selection is missing/invalid — covers persisted drafts
/// still carrying legacy fallback ids ('budget', 'standard', 'premium') and
/// tiers that were deactivated/deleted since the draft was saved. A null
/// result means "treat as unselected": the picker replaces it with the
/// first active tier so Continue can never proceed on an invisible,
/// invalid selection.
EventTier? resolveSelectedTier(List<EventTier> tiers, String? selectedId) {
  if (selectedId == null) return null;
  for (final t in tiers) {
    if (t.id == selectedId) return t;
  }
  return null;
}

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
final restaurantsForTierProvider =
    FutureProvider.family<List<Restaurant>, RestaurantsForTierArgs>(
        (ref, args) async {
  final repo = ref.watch(eventTierRepositoryProvider);
  return repo.restaurantsForTier(
    tierId: args.tierId,
    latitude: args.latitude,
    longitude: args.longitude,
    radiusKm: args.radiusKm,
  );
});
