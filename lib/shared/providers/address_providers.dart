import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_address.dart';
import 'auth_providers.dart';
import 'repositories_providers.dart';

final addressesProvider =
    FutureProvider<List<UserAddress>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.read(addressRepositoryProvider).fetchForUser(userId);
});

final defaultAddressProvider = Provider<UserAddress?>((ref) {
  final list = ref.watch(addressesProvider).valueOrNull ?? const [];
  if (list.isEmpty) return null;
  return list.firstWhere(
    (a) => a.isDefault,
    orElse: () => list.first,
  );
});

/// Explicitly-selected address (e.g. from the header chip). Falls back to
/// the default address when null.
final selectedAddressIdProvider = StateProvider<String?>((_) => null);

/// The address that drives the "nearby restaurants" query + the home chip.
/// Resolves the manually-selected address first, then the default, then the
/// first saved address.
final activeAddressProvider = Provider<UserAddress?>((ref) {
  final selectedId = ref.watch(selectedAddressIdProvider);
  final list = ref.watch(addressesProvider).valueOrNull ?? const [];
  if (list.isEmpty) return null;
  if (selectedId != null) {
    for (final a in list) {
      if (a.id == selectedId) return a;
    }
  }
  return ref.watch(defaultAddressProvider);
});
