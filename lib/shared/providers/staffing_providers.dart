import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/event_assignment.dart';
import '../../data/models/user_profile.dart';
import 'auth_providers.dart';
import 'repositories_providers.dart';

/// Live stream of events the current user is assigned to.
/// Used by both manager and service-boy home screens — role-specific
/// filtering (only service boys, only managed-by-me) is applied in UI.
///
/// Watches [currentUserIdProvider] so the stream resubscribes whenever
/// the signed-in account changes — without that, switching via the
/// dev sign-in panel (or any other multi-account flow) would leave
/// the previous user's filtered stream attached and the new user
/// would see an empty list even though their assignments exist.
final myAssignmentsProvider =
    StreamProvider<List<EventAssignment>>((ref) async* {
  ref.watch(currentUserIdProvider);
  final repo = ref.watch(staffingRepositoryProvider);
  yield* repo.streamMyAssignments();
});

/// Service boys under the currently signed-in manager (direct reports).
/// Same auth-aware rebuild pattern as [myAssignmentsProvider] so the
/// manager's report list refreshes when accounts are swapped.
final myReportsProvider = FutureProvider<List<UserProfile>>((ref) async {
  ref.watch(currentUserIdProvider);
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
