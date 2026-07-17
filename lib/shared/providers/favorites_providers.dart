import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/restaurant.dart';
import 'repositories_providers.dart';

/// Local-only favorite menu item IDs. Persists with SharedPreferences.
/// When you later want favorites synced to Supabase, swap the backing impl.
class FavoritesController extends AsyncNotifier<Set<String>> {
  static const _key = 'dawat.favorites.v1';

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> toggle(String itemId) async {
    final current = state.valueOrNull ?? <String>{};
    final next = {...current};
    if (next.contains(itemId)) {
      next.remove(itemId);
    } else {
      next.add(itemId);
    }
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesController, Set<String>>(
  FavoritesController.new,
);

final isFavoriteProvider = Provider.family<bool, String>((ref, id) {
  final s = ref.watch(favoritesProvider).valueOrNull ?? const <String>{};
  return s.contains(id);
});

/// Favorited restaurants resolved BY ID (any lifecycle state), so a favorite
/// never silently vanishes just because it's outside the current nearby/tier
/// scope. Non-published rows come back too — the screen labels them
/// "unavailable" instead of dropping them.
final favoriteRestaurantsProvider =
    FutureProvider<List<Restaurant>>((ref) async {
  final favSet = ref.watch(favoritesProvider).valueOrNull ?? const <String>{};
  // Guard against legacy empty-string ids from the old blank-shell bug.
  final ids = favSet.where((id) => id.isNotEmpty).toSet();
  if (ids.isEmpty) return const [];
  final list = await ref.read(menuRepositoryProvider).fetchRestaurantsByIds(
        ids,
      );
  list.sort((a, b) => a.name.compareTo(b.name));
  return list;
});
