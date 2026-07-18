import '../models/banquet_venue.dart';
import '../models/user_profile.dart';

/// Contract for the banquet operator side: list venues they own, read the
/// inbox of events routed to those venues, accept/decline events, and manage
/// per-venue equipment inventory.
abstract interface class BanquetRepository {
  /// Venues owned by the currently signed-in banquet operator.
  Future<List<BanquetVenue>> fetchMyVenues();

  /// Every active venue — used by the customer-side venue picker.
  /// (RLS: banquet_venues has a public-read policy for exactly this.)
  Future<List<BanquetVenue>> fetchAllVenues();

  /// Active venues with valid coordinates within [radiusKm] of the event
  /// point, nearest-first, each carrying [BanquetVenue.distanceKm]. Venues
  /// whose KNOWN capacity is below [minCapacity] are excluded; unknown
  /// capacity stays visible. NOTE: the tap-time gate and place_order's
  /// server check also only protect venues with a KNOWN capacity — a
  /// null-capacity venue is never blocked anywhere.
  /// The server clamps the radius to 1..100 km regardless of what's passed.
  Future<List<BanquetVenue>> venuesNear({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int? minCapacity,
  });

  /// All events routed to venues the operator owns, newest first.
  Future<List<BanquetInboxEvent>> fetchInbox();

  /// Streaming variant for realtime updates. Initial REST fetch first, then
  /// overlay realtime changes.
  Stream<List<BanquetInboxEvent>> streamInbox();

  Future<void> updateEventStatus({
    required String eventId,
    required BanquetEventStatus status,
    String? notes,
  });

  /// Operator-only note attached to a booking. Pass an empty string to
  /// clear it. Status is left untouched.
  Future<void> updateEventNotes({
    required String eventId,
    required String notes,
  });

  Future<List<BanquetInventoryItem>> fetchInventory(String venueId);

  Future<void> updateInventoryItem({
    required String itemId,
    required double unitPrice,
    required bool perGuest,
    required bool isActive,
  });

  /// Manager profiles — used by the banquet operator to pick one for an
  /// accepted event. Admins can expand this to filter by "works for this
  /// banquet" later; for MVP every `role='manager'` profile is eligible.
  Future<List<UserProfile>> fetchAvailableManagers();

  // ── Admin venue management (phase 40) ──────────────────────────────────
  // Venues used to be hand-inserted in the database, which is how rows
  // without coordinates could exist. These methods back the admin console's
  // venue manager; the DB additionally enforces that ACTIVE venues carry an
  // address + coordinates (banquet_venues_active_needs_location).

  /// Every venue in ANY state (active + inactive) — admin console list.
  Future<List<BanquetVenue>> fetchVenuesAdmin();

  /// Create a venue owned by [ownerProfileId]. Returns the inserted row.
  Future<BanquetVenue> createVenue({
    required String ownerProfileId,
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    int? capacity,
    required bool isActive,
  });

  /// Update a venue. All fields are written (null clears the nullable ones),
  /// so callers pass the complete desired state. Returns the updated row.
  Future<BanquetVenue> updateVenue({
    required String venueId,
    required String ownerProfileId,
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    int? capacity,
    required bool isActive,
  });

  /// Banquet-operator profiles (`role='banquet'`) — the admin assigns one
  /// as the owner when onboarding a venue.
  Future<List<UserProfile>> fetchBanquetOperators();
}
