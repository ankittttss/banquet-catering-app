import '../models/event_assignment.dart';
import '../models/user_profile.dart';

/// Staffing view from the manager + service-boy perspective.
/// Banquet-side assignment (assigning a manager to an event) lives in
/// [BanquetRepository] so the operator inbox keeps a single surface.
abstract interface class StaffingRepository {
  /// Assignments where [profileId] = current user, newest event first.
  /// Populates joined event metadata.
  Future<List<EventAssignment>> fetchMyAssignments();

  Stream<List<EventAssignment>> streamMyAssignments();

  /// All staff on a given event (used by the manager's event detail).
  Future<List<EventAssignment>> fetchAssignmentsForEvent(String eventId);

  /// Manager sees service boys under them (profiles.reports_to_manager_id).
  Future<List<UserProfile>> fetchMyReports();

  Future<void> addServiceBoyAssignment({
    required String eventId,
    required String profileId,
  });

  Future<void> removeAssignment(String assignmentId);

  Future<void> checkIn(String assignmentId);
  Future<void> checkOut(String assignmentId);

  /// Banquet-side helper: set the single manager for an event.
  Future<void> setEventManager({
    required String eventId,
    required String managerProfileId,
  });
}
