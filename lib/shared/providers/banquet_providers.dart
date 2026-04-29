import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/banquet_venue.dart';
import '../../data/models/user_profile.dart';
import 'repositories_providers.dart';

/// Venues owned by the currently signed-in banquet operator.
final myBanquetVenuesProvider =
    FutureProvider<List<BanquetVenue>>((ref) async {
  final repo = ref.watch(banquetRepositoryProvider);
  return repo.fetchMyVenues();
});

/// Public catalog of every active venue — used by the customer-side picker.
final allBanquetVenuesProvider =
    FutureProvider<List<BanquetVenue>>((ref) async {
  final repo = ref.watch(banquetRepositoryProvider);
  return repo.fetchAllVenues();
});

/// Live inbox of incoming events for the operator's venues.
final banquetInboxProvider =
    StreamProvider<List<BanquetInboxEvent>>((ref) async* {
  final repo = ref.watch(banquetRepositoryProvider);
  yield* repo.streamInbox();
});

/// Inventory for a single venue.
final banquetInventoryProvider = FutureProvider.family<
    List<BanquetInventoryItem>, String>((ref, venueId) async {
  final repo = ref.watch(banquetRepositoryProvider);
  return repo.fetchInventory(venueId);
});

/// Manager profiles the banquet operator can assign to an event.
/// autoDispose so closing + reopening the Assign Manager sheet forces a
/// fresh fetch — avoids the case where an empty result cached during
/// early-session RLS setup sticks around after the admin widens policies.
final availableManagersProvider =
    FutureProvider.autoDispose<List<UserProfile>>((ref) async {
  final repo = ref.watch(banquetRepositoryProvider);
  return repo.fetchAvailableManagers();
});
