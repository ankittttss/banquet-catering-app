import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
