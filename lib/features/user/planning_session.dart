import '../../data/models/cart_item.dart';
import '../../data/models/event_draft.dart';
import '../../data/models/restaurant.dart';
import '../../data/repositories/menu_repository.dart';
import '../../shared/providers/cart_providers.dart';
import '../../shared/providers/event_providers.dart';
import 'location_change.dart';

/// Non-widget planning mutations for the transactional plan-edit flows.
/// Everything here is a plain function over the draft/cart notifiers (no
/// [BuildContext]), so confirm/cancel/apply logic is unit-testable via a
/// [ProviderContainer] and the UI is a thin shell that decides only WHEN.

/// Thrown when a proposed event location or venue cannot be pinned. Callers
/// must change nothing and tell the customer to pick a locatable address.
class UnlocatableCandidate implements Exception {
  const UnlocatableCandidate(this.what);

  /// Human label of the thing that couldn't be pinned ("this address").
  final String what;

  @override
  String toString() => 'UnlocatableCandidate($what)';
}

/// Whether applying a new event location will drop the private-property address
/// details. [EventDraftController.setEventLocation] keeps only the property
/// TYPE, so address fields are cleared when any is set.
bool eventLocationChangeClearsProperty(EventDraft draft) {
  final p = draft.propertyDraft;
  if (p == null) return false;
  bool has(String? v) => v != null && v.trim().isNotEmpty;
  return has(p.addressLine1) || has(p.landmark) || has(p.cityPincode);
}

/// Transactional PREVIEW of moving the event to [candidate]: resolves the
/// cart's restaurants, their live status and dish availability, then computes
/// exactly which lines become invalid. Throws if a lookup fails (caller offers
/// Retry). Mutates nothing.
Future<LocationImpact> checkEventLocationChange({
  required LocationCandidate candidate,
  required EventDraft draft,
  required List<CartItem> cart,
  required MenuRepository repository,
}) async {
  final resolved = await _resolveCart(cart, repository);
  return computeLocationImpact(
    latitude: candidate.latitude,
    longitude: candidate.longitude,
    cart: cart,
    cartRestaurants: resolved.restaurants,
    inactiveRestaurantIds: resolved.inactiveRestaurantIds,
    unavailableItemIds: resolved.unavailableItemIds,
    venueWillClear: draft.banquetVenueId != null,
    propertyWillClear: eventLocationChangeClearsProperty(draft),
  );
}

/// Transactional PREVIEW of selecting a banquet venue whose coordinates become
/// the event location. A venue without a usable pin is REJECTED — it cannot be
/// made the authoritative event location.
///
/// Throws [UnlocatableCandidate] for an unpinnable venue.
Future<LocationImpact> checkBanquetVenueImpact({
  required double? venueLatitude,
  required double? venueLongitude,
  required List<CartItem> cart,
  required MenuRepository repository,
}) async {
  if (!hasUsableCoords(venueLatitude, venueLongitude)) {
    throw const UnlocatableCandidate('this venue');
  }
  if (cart.isEmpty) return LocationImpact.none;
  final resolved = await _resolveCart(cart, repository);
  return computeLocationImpact(
    latitude: venueLatitude!,
    longitude: venueLongitude!,
    cart: cart,
    cartRestaurants: resolved.restaurants,
    inactiveRestaurantIds: resolved.inactiveRestaurantIds,
    unavailableItemIds: resolved.unavailableItemIds,
    venueWillClear: false,
    propertyWillClear: false,
  );
}

typedef _ResolvedCart = ({
  Map<String, Restaurant> restaurants,
  Set<String> inactiveRestaurantIds,
  Set<String> unavailableItemIds,
});

/// One round trip for everything the impact check needs: live restaurant rows,
/// which of them are no longer active, and which dishes are no longer served.
Future<_ResolvedCart> _resolveCart(
  List<CartItem> cart,
  MenuRepository repository,
) async {
  final restaurantIds = cart.map((l) => l.item.restaurantId).toSet();
  final itemIds = cart.map((l) => l.item.id).toSet();
  if (restaurantIds.isEmpty) {
    return (
      restaurants: const <String, Restaurant>{},
      inactiveRestaurantIds: const <String>{},
      unavailableItemIds: const <String>{},
    );
  }
  final results = await Future.wait([
    repository.fetchRestaurantsByIds(restaurantIds),
    repository.fetchInactiveRestaurantIds(restaurantIds),
    repository.fetchUnavailableItemIds(itemIds),
  ]);
  final rows = results[0] as List<Restaurant>;
  return (
    restaurants: {for (final r in rows) r.id: r},
    inactiveRestaurantIds: results[1] as Set<String>,
    unavailableItemIds: results[2] as Set<String>,
  );
}

/// Applies a confirmed location change in ONE step: sets the new event location
/// (which clears any banquet venue + property address) and removes exactly the
/// cart lines that can't survive it. Call ONLY after confirmation.
void applyEventLocationChange({
  required EventDraftController draftController,
  required CartController cartController,
  required LocationCandidate candidate,
  required LocationImpact impact,
}) {
  draftController.setEventLocation(
    address: candidate.address,
    latitude: candidate.latitude,
    longitude: candidate.longitude,
  );
  _removeLines(cartController, impact.removedSignatures);
}

/// Applies a confirmed banquet-venue change: the venue becomes the
/// authoritative event location, and invalid cart lines are removed. The venue
/// MUST be pinnable — an unlocatable venue is rejected, never applied.
void applyBanquetVenueChange({
  required EventDraftController draftController,
  required CartController cartController,
  required String venueId,
  required String venueName,
  String? address,
  double? latitude,
  double? longitude,
  int? capacity,
  required LocationImpact impact,
}) {
  if (!hasUsableCoords(latitude, longitude)) {
    throw const UnlocatableCandidate('this venue');
  }
  draftController.setBanquetVenue(
    venueId: venueId,
    venueName: venueName,
    address: address,
    latitude: latitude,
    longitude: longitude,
    capacity: capacity,
  );
  _removeLines(cartController, impact.removedSignatures);
}

/// "Start fresh": clears the event draft AND the cart — and nothing else. Saved
/// addresses, profile, favourites and order history live in their own
/// repositories, so they are untouched.
void clearPlanningSession({
  required EventDraftController draftController,
  required CartController cartController,
}) {
  draftController.reset();
  cartController.clear();
}

void _removeLines(CartController cartController, List<String> signatures) {
  for (final sig in signatures) {
    cartController.removeLine(sig);
  }
}
