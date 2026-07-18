import '../../models/banquet_venue.dart';
import '../../models/user_profile.dart';
import '../banquet_repository.dart';

class StubBanquetRepository implements BanquetRepository {
  @override
  Future<List<BanquetVenue>> fetchMyVenues() async => const [];

  @override
  Future<List<BanquetVenue>> fetchAllVenues() async => const [];

  @override
  Future<List<BanquetInboxEvent>> fetchInbox() async => const [];

  @override
  Stream<List<BanquetInboxEvent>> streamInbox() async* {
    yield const [];
  }

  @override
  Future<void> updateEventStatus({
    required String eventId,
    required BanquetEventStatus status,
    String? notes,
  }) async {
    // No-op in stub mode.
  }

  @override
  Future<void> updateEventNotes({
    required String eventId,
    required String notes,
  }) async {
    // No-op in stub mode.
  }

  @override
  Future<List<BanquetInventoryItem>> fetchInventory(String venueId) async =>
      const [];

  @override
  Future<void> updateInventoryItem({
    required String itemId,
    required double unitPrice,
    required bool perGuest,
    required bool isActive,
  }) async {
    // No-op in stub mode.
  }

  @override
  Future<List<UserProfile>> fetchAvailableManagers() async => const [];

  // ── Admin venue management ────────────────────────────────────────────
  // In-memory store so the admin venue screen is exercisable offline.

  final List<BanquetVenue> _venues = [];
  int _nextId = 1;

  @override
  Future<List<BanquetVenue>> fetchVenuesAdmin() async =>
      List.unmodifiable(_venues);

  @override
  Future<BanquetVenue> createVenue({
    required String ownerProfileId,
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    int? capacity,
    required bool isActive,
  }) async {
    final venue = BanquetVenue(
      id: 'stub-venue-${_nextId++}',
      ownerProfileId: ownerProfileId,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      capacity: capacity,
      isActive: isActive,
    );
    _venues.add(venue);
    return venue;
  }

  @override
  Future<BanquetVenue> updateVenue({
    required String venueId,
    required String ownerProfileId,
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    int? capacity,
    required bool isActive,
  }) async {
    final venue = BanquetVenue(
      id: venueId,
      ownerProfileId: ownerProfileId,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      capacity: capacity,
      isActive: isActive,
    );
    final i = _venues.indexWhere((v) => v.id == venueId);
    if (i >= 0) {
      _venues[i] = venue;
    } else {
      _venues.add(venue);
    }
    return venue;
  }

  @override
  Future<List<UserProfile>> fetchBanquetOperators() async => const [];
}
