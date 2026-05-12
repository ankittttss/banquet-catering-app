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
    // Newest received first — operators want to see what just landed,
    // not what's happening earliest on the calendar.
    final rows = await supabase
        .from('events')
        .select()
        .not('banquet_venue_id', 'is', null)
        .order('created_at', ascending: false);
    final events = rows
        .map<BanquetInboxEvent>(BanquetInboxEvent.fromMap)
        .toList(growable: false);
    return _attachCustomers(events);
  }

  /// Hydrates the customer name/phone/email on a list of inbox events
  /// via one extra batched profile lookup. RLS (phase 28) lets the
  /// operator read just the customer rows tied to bookings at their
  /// venues; if the lookup fails for any reason the events still come
  /// back, just without customer info.
  Future<List<BanquetInboxEvent>> _attachCustomers(
    List<BanquetInboxEvent> events,
  ) async {
    final ids = <String>{
      for (final e in events)
        if (e.userId != null && e.userId!.isNotEmpty) e.userId!,
    }.toList(growable: false);
    if (ids.isEmpty) return events;
    Map<String, Map<String, dynamic>> byId = {};
    try {
      final profileRows = await supabase
          .from('profiles')
          .select('id, name, phone, email')
          .inFilter('id', ids);
      byId = {
        for (final p in profileRows)
          (p as Map)['id'] as String: p.cast<String, dynamic>(),
      };
    } catch (_) {
      // Profile read may be denied for some events (e.g. customer
      // deactivated their account). Fall back to id-only display in UI.
    }
    return [
      for (final e in events)
        () {
          final p = e.userId != null ? byId[e.userId!] : null;
          if (p == null) return e;
          return e.withCustomer(
            name: p['name'] as String?,
            phone: p['phone'] as String?,
            email: p['email'] as String?,
          );
        }(),
    ];
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
          .order('created_at', ascending: false);
      await for (final rows in stream) {
        final events = rows
            .where((r) => r['banquet_venue_id'] != null)
            .map<BanquetInboxEvent>(BanquetInboxEvent.fromMap)
            .toList(growable: false);
        yield await _attachCustomers(events);
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
  Future<void> updateEventNotes({
    required String eventId,
    required String notes,
  }) async {
    // Empty string explicitly clears the note (vs. leaving it null in
    // the partial update — a Postgres update of "" is what the
    // operator-update RLS policy was written to allow).
    await supabase
        .from('events')
        .update({'banquet_notes': notes})
        .eq('id', eventId);
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
