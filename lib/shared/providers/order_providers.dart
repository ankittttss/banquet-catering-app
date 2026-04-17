import 'package:flutter_riverpod/flutter_riverpod.dart';

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
