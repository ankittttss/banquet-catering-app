import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/event_assignment.dart';
import '../../data/models/user_profile.dart';
import 'repositories_providers.dart';

/// Live stream of events the current user is assigned to.
/// Used by both manager and service-boy home screens — role-specific
/// filtering (only service boys, only managed-by-me) is applied in UI.
final myAssignmentsProvider =
    StreamProvider<List<EventAssignment>>((ref) async* {
  final repo = ref.watch(staffingRepositoryProvider);
  yield* repo.streamMyAssignments();
});

/// Service boys under the currently signed-in manager (direct reports).
final myReportsProvider = FutureProvider<List<UserProfile>>((ref) async {
  final repo = ref.watch(staffingRepositoryProvider);
  return repo.fetchMyReports();
});

/// Full roster for a given event (manager + every service boy on it).
/// autoDispose so navigating away from the inbox + back forces a refetch —
/// cached empty results (from a first load before any assignments existed)
/// would otherwise stick until the app restarts.
final eventStaffProvider = FutureProvider.autoDispose
    .family<List<EventAssignment>, String>((ref, eventId) async {
  final repo = ref.watch(staffingRepositoryProvider);
  return repo.fetchAssignmentsForEvent(eventId);
});
