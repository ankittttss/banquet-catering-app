import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/manager_event_detail.dart';
import '../../data/models/order.dart';
import 'auth_providers.dart';
import 'repositories_providers.dart';

/// Realtime stream of the current user's orders, newest first.
final myOrdersStreamProvider =
    StreamProvider<List<OrderSummary>>((ref) {
  final uid = ref.watch(currentUserIdProvider) ?? 'local';
  return ref.read(orderRepositoryProvider).streamMyOrders(uid);
});

/// Single-order lookup by id. Built on top of the stream so it auto-updates.
final orderByIdProvider =
    Provider.family<OrderSummary?, String>((ref, id) {
  final list = ref.watch(myOrdersStreamProvider).valueOrNull ?? const [];
  try {
    return list.firstWhere((o) => o.id == id);
  } catch (_) {
    return null;
  }
});

/// Aggregated event-level snapshot used by the manager event-detail
/// screen. autoDispose so the cache is dropped when the manager leaves
/// the screen — keeps the list lightweight and forces a fresh fetch on
/// the next open.
final managerEventDetailProvider = FutureProvider.autoDispose
    .family<ManagerEventDetail?, String>((ref, eventId) async {
  return ref.read(orderRepositoryProvider).fetchEventDetail(eventId);
});
