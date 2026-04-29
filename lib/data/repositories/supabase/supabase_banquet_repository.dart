import '../../../core/supabase/supabase_client.dart';
import '../../models/banquet_venue.dart';
import '../../models/user_profile.dart';
import '../banquet_repository.dart';

class SupabaseBanquetRepository implements BanquetRepository {
  @override
  Future<List<BanquetVenue>> fetchMyVenues() async {
    final uid = auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await supabase
        .from('banquet_venues')
        .select()
        .eq('owner_profile_id', uid)
        .order('created_at', ascending: false);
    return rows.map<BanquetVenue>(BanquetVenue.fromMap).toList(growable: false);
  }

  @override
  Future<List<BanquetVenue>> fetchAllVenues() async {
    final rows = await supabase
        .from('banquet_venues')
        .select()
        .eq('is_active', true)
        .order('name');
    return rows.map<BanquetVenue>(BanquetVenue.fromMap).toList(growable: false);
  }

  @override
  Future<List<BanquetInboxEvent>> fetchInbox() async {
    final rows = await supabase
        .from('events')
        .select()
        .not('banquet_venue_id', 'is', null)
        .order('event_date', ascending: true);
    return rows
        .map<BanquetInboxEvent>(BanquetInboxEvent.fromMap)
        .toList(growable: false);
  }

  @override
  Stream<List<BanquetInboxEvent>> streamInbox() async* {
    // Initial fetch (RLS scopes to venues the operator owns).
    try {
      final initial = await fetchInbox();
      yield initial;
    } catch (_) {
      yield const [];
    }

    // Realtime overlay. RLS still filters, so client-side filtering is
    // only needed for rows the realtime payload might include (defensive).
    try {
      final stream = supabase
          .from('events')
          .stream(primaryKey: ['id'])
          .order('event_date', ascending: true);
      await for (final rows in stream) {
        yield rows
            .where((r) => r['banquet_venue_id'] != null)
            .map<BanquetInboxEvent>(BanquetInboxEvent.fromMap)
            .toList(growable: false);
      }
    } catch (_) {
      // Realtime unavailable — initial snapshot already surfaced.
    }
  }

  @override
  Future<void> updateEventStatus({
    required String eventId,
    required BanquetEventStatus status,
    String? notes,
  }) async {
    await supabase.from('events').update({
      'banquet_status': status.dbValue,
      if (notes != null) 'banquet_notes': notes,
    }).eq('id', eventId);
  }

  @override
  Future<List<UserProfile>> fetchAvailableManagers() async {
    final rows = await supabase
        .from('profiles')
        .select()
        .eq('role', 'manager')
        .order('name');
    return rows
        .map<UserProfile>(UserProfile.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<BanquetInventoryItem>> fetchInventory(String venueId) async {
    final rows = await supabase
        .from('banquet_inventory')
        .select()
        .eq('venue_id', venueId)
        .eq('is_active', true)
        .order('sort_order');
    return rows
        .map<BanquetInventoryItem>(BanquetInventoryItem.fromMap)
        .toList(growable: false);
  }
}
