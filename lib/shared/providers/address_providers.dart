import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_address.dart';
import 'auth_providers.dart';
import 'repositories_providers.dart';

final addressesProvider =
    FutureProvider.autoDispose<List<UserAddress>>((ref) async {
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
