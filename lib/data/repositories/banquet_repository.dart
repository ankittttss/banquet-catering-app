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

  Future<List<BanquetInventoryItem>> fetchInventory(String venueId);

  /// Manager profiles — used by the banquet operator to pick one for an
  /// accepted event. Admins can expand this to filter by "works for this
  /// banquet" later; for MVP every `role='manager'` profile is eligible.
  Future<List<UserProfile>> fetchAvailableManagers();
}
