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
}
