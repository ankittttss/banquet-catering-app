import '../../models/event_assignment.dart';
import '../../models/user_profile.dart';
import '../staffing_repository.dart';

class StubStaffingRepository implements StaffingRepository {
  @override
  Future<List<EventAssignment>> fetchMyAssignments() async => const [];

  @override
  Stream<List<EventAssignment>> streamMyAssignments() async* {
    yield const [];
  }

  @override
  Future<List<EventAssignment>> fetchAssignmentsForEvent(
          String eventId) async =>
      const [];

  @override
  Future<List<UserProfile>> fetchMyReports() async => const [];

  @override
  Future<void> addServiceBoyAssignment({
    required String eventId,
    required String profileId,
  }) async {}

  @override
  Future<void> removeAssignment(String assignmentId) async {}

  @override
  Future<void> checkIn(String assignmentId) async {}

  @override
  Future<void> checkOut(String assignmentId) async {}

  @override
  Future<void> setEventManager({
    required String eventId,
    required String managerProfileId,
  }) async {}
}
