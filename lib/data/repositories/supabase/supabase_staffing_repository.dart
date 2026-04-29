import '../../../core/supabase/supabase_client.dart';
import '../../models/event_assignment.dart';
import '../../models/user_profile.dart';
import '../staffing_repository.dart';

class SupabaseStaffingRepository implements StaffingRepository {
  @override
  Future<List<EventAssignment>> fetchMyAssignments() async {
    final uid = auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await supabase
        .from('event_assignments')
        .select(
            // Disambiguate the FK embed: event_assignments has TWO FKs to profiles
// (profile_id + assigned_by), so PostgREST needs the constraint name.
'*, events(event_date, location, session, guest_count), '
            'assignee:profiles!event_assignments_profile_id_fkey(name)')
        .eq('profile_id', uid)
        .order('assigned_at', ascending: false);
    return rows
        .map<EventAssignment>(EventAssignment.fromMap)
        .toList(growable: false);
  }

  @override
  Stream<List<EventAssignment>> streamMyAssignments() async* {
    try {
      yield await fetchMyAssignments();
    } catch (_) {
      yield const [];
    }
    try {
      final uid = auth.currentUser?.id;
      if (uid == null) return;
      final stream = supabase
          .from('event_assignments')
          .stream(primaryKey: ['id'])
          .eq('profile_id', uid);
      await for (final _ in stream) {
        yield await fetchMyAssignments();
      }
    } catch (_) {
      // Realtime unavailable — initial snapshot already surfaced.
    }
  }

  @override
  Future<List<EventAssignment>> fetchAssignmentsForEvent(
      String eventId) async {
    final rows = await supabase
        .from('event_assignments')
        .select(
            // Disambiguate the FK embed: event_assignments has TWO FKs to profiles
// (profile_id + assigned_by), so PostgREST needs the constraint name.
'*, events(event_date, location, session, guest_count), '
            'assignee:profiles!event_assignments_profile_id_fkey(name)')
        .eq('event_id', eventId)
        .order('role_on_event');
    return rows
        .map<EventAssignment>(EventAssignment.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<UserProfile>> fetchMyReports() async {
    final uid = auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await supabase
        .from('profiles')
        .select()
        .eq('reports_to_manager_id', uid)
        .order('name');
    return rows
        .map<UserProfile>(UserProfile.fromMap)
        .toList(growable: false);
  }

  @override
  Future<void> addServiceBoyAssignment({
    required String eventId,
    required String profileId,
  }) async {
    await supabase.from('event_assignments').insert({
      'event_id': eventId,
      'profile_id': profileId,
      'role_on_event': 'service_boy',
      'assigned_by': auth.currentUser?.id,
    });
  }

  @override
  Future<void> removeAssignment(String assignmentId) async {
    await supabase
        .from('event_assignments')
        .delete()
        .eq('id', assignmentId);
  }

  @override
  Future<void> checkIn(String assignmentId) async {
    await supabase
        .from('event_assignments')
        .update({'checked_in_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', assignmentId);
  }

  @override
  Future<void> checkOut(String assignmentId) async {
    await supabase
        .from('event_assignments')
        .update({'checked_out_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', assignmentId);
  }

  @override
  Future<void> setEventManager({
    required String eventId,
    required String managerProfileId,
  }) async {
    // Remove any existing manager assignment first (single-manager constraint).
    await supabase
        .from('event_assignments')
        .delete()
        .eq('event_id', eventId)
        .eq('role_on_event', 'manager');

    await supabase.from('event_assignments').insert({
      'event_id': eventId,
      'profile_id': managerProfileId,
      'role_on_event': 'manager',
      'assigned_by': auth.currentUser?.id,
    });
  }
}
