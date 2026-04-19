import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/models/delivery_assignment.dart';
import '../../data/models/driver_profile.dart';
import 'auth_providers.dart';
import 'repositories_providers.dart';

/// The currently signed-in driver id. When Supabase is configured, reads the
/// auth user id; in dev (stub) mode falls back to `'me'`, which the stub
/// seeds.
final currentDriverIdProvider = Provider<String>((ref) {
  if (!AppConfig.hasSupabase) return 'me';
  return ref.watch(currentUserIdProvider) ?? 'me';
});

final currentDriverProvider = StreamProvider<DriverProfile>((ref) {
  final id = ref.watch(currentDriverIdProvider);
  return ref.watch(deliveryRepositoryProvider).streamDriver(id);
});

final deliveryOffersProvider =
    StreamProvider<List<DeliveryAssignment>>((ref) {
  return ref.watch(deliveryRepositoryProvider).streamOffers();
});

final activeDeliveryProvider =
    StreamProvider<DeliveryAssignment?>((ref) {
  final id = ref.watch(currentDriverIdProvider);
  return ref.watch(deliveryRepositoryProvider).streamActive(id);
});

final deliveryHistoryProvider =
    FutureProvider.autoDispose<List<DeliveryAssignment>>((ref) {
  final id = ref.watch(currentDriverIdProvider);
  return ref.watch(deliveryRepositoryProvider).fetchHistory(id);
});
