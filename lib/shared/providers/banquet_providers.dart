import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/banquet_venue.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/venue_type.dart';
import 'event_providers.dart';
import 'repositories_providers.dart';

/// Venues owned by the currently signed-in banquet operator.
final myBanquetVenuesProvider = FutureProvider<List<BanquetVenue>>((ref) async {
  final repo = ref.watch(banquetRepositoryProvider);
  return repo.fetchMyVenues();
});

/// Public catalog of every active venue. (The customer picker now uses the
/// location-scoped [nearbyVenuesProvider]; this remains for admin-side
/// invalidation and any non-geographic listing.)
final allBanquetVenuesProvider =
    FutureProvider<List<BanquetVenue>>((ref) async {
  final repo = ref.watch(banquetRepositoryProvider);
  return repo.fetchAllVenues();
});

/// Customer venue-picker search radius in km. Hard default 50; the picker's
/// "Expand search" flips it to 100 (the server clamps at 100 anyway).
/// autoDispose: resets to 50 whenever the picker closes, so a widened
/// search never silently leaks into the next event.
final venueSearchRadiusProvider = StateProvider.autoDispose<double>((_) => 50);

/// Active venues near the EVENT location, nearest-first with distances.
/// Intentionally keyed to the event draft's own coordinates — never the
/// saved home address: the picker only exists mid-planning, and venues
/// across the country are useless for an event in another city. Returns
/// const [] when the draft has no coordinates (the picker shows its
/// "confirm your event location" state instead of calling blind).
final nearbyVenuesProvider =
    FutureProvider.autoDispose<List<BanquetVenue>>((ref) async {
  final draft = ref.watch(eventDraftProvider);
  if (!draft.hasEventCoords) return const [];
  final radius = ref.watch(venueSearchRadiusProvider);
  final repo = ref.watch(banquetRepositoryProvider);
  return repo.venuesNear(
    latitude: draft.eventLatitude!,
    longitude: draft.eventLongitude!,
    radiusKm: radius,
    minCapacity: draft.guestCount,
  );
});

/// Live inbox of incoming events for the operator's venues.
final banquetInboxProvider =
    StreamProvider<List<BanquetInboxEvent>>((ref) async* {
  final repo = ref.watch(banquetRepositoryProvider);
  yield* repo.streamInbox();
});

/// Inventory for a single venue.
final banquetInventoryProvider =
    FutureProvider.family<List<BanquetInventoryItem>, String>(
        (ref, venueId) async {
  final repo = ref.watch(banquetRepositoryProvider);
  return repo.fetchInventory(venueId);
});

/// Manager profiles the banquet operator can assign to an event.
/// autoDispose so closing + reopening the Assign Manager sheet forces a
/// fresh fetch — avoids the case where an empty result cached during
/// early-session RLS setup sticks around after the admin widens policies.
final availableManagersProvider =
    FutureProvider.autoDispose<List<UserProfile>>((ref) async {
  final repo = ref.watch(banquetRepositoryProvider);
  return repo.fetchAvailableManagers();
});

/// Every venue in any state — admin console venue manager.
final adminVenuesProvider =
    FutureProvider.autoDispose<List<BanquetVenue>>((ref) async {
  final repo = ref.watch(banquetRepositoryProvider);
  return repo.fetchVenuesAdmin();
});

/// Banquet-operator profiles the admin can assign as a venue's owner.
final banquetOperatorsProvider =
    FutureProvider.autoDispose<List<UserProfile>>((ref) async {
  final repo = ref.watch(banquetRepositoryProvider);
  return repo.fetchBanquetOperators();
});

/// Whether the banquet venue currently on the draft is still usable.
enum VenueCheckState {
  /// No banquet venue is selected (or the flow isn't banquet-hall).
  none,

  /// The venue exists, is active, and fits the guest count.
  valid,

  /// The venue is active but its known capacity is below the guest count.
  tooSmall,

  /// The venue was deleted or deactivated since it was selected.
  unavailable,
}

/// Result of reconciling the draft's selected banquet venue against LIVE
/// data. Carries the fresh venue row (address/capacity) for the summary card.
class VenueCheck {
  const VenueCheck(this.state, {this.venue});
  final VenueCheckState state;
  final BanquetVenue? venue;

  bool get isBlocking =>
      state == VenueCheckState.tooSmall || state == VenueCheckState.unavailable;
}

/// Re-validates the draft's selected banquet venue against live data by id:
/// the venue must still exist, still be active (the `fetchActiveVenueById`
/// read is active-only under RLS) and still fit the current guest count.
///
/// This is a client-side COMPLEMENT to the server: `place_order` remains the
/// final authority (it re-checks active + capacity + coordinates), but this
/// lets the venue screen surface a stale/too-small selection immediately
/// instead of only at checkout. A network error surfaces as AsyncError so
/// the screen can offer Retry and keep Continue blocked — it never silently
/// clears a selection.
final selectedBanquetVenueCheckProvider =
    FutureProvider.autoDispose<VenueCheck>((ref) async {
  final draft = ref.watch(eventDraftProvider);
  if (draft.venueType != VenueType.banquetHall ||
      draft.banquetVenueId == null) {
    return const VenueCheck(VenueCheckState.none);
  }
  final repo = ref.watch(banquetRepositoryProvider);
  final venue = await repo.fetchActiveVenueById(draft.banquetVenueId!);
  if (venue == null) return const VenueCheck(VenueCheckState.unavailable);
  final tooSmall = venue.capacity != null && draft.guestCount > venue.capacity!;
  return VenueCheck(
    tooSmall ? VenueCheckState.tooSmall : VenueCheckState.valid,
    venue: venue,
  );
});
