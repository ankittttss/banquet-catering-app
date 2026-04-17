import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/trending_search.dart';
import 'repositories_providers.dart';

/// Trending chips on the Search screen — admin-managed, from Supabase.
final trendingSearchesProvider =
    FutureProvider<List<TrendingSearch>>((ref) async {
  return ref.read(taxonomyRepositoryProvider).fetchTrendingSearches();
});

/// User's recent search queries, persisted locally. Kept separate from the
/// backend — trending is global curation, recents are private history.
class RecentSearchesController extends AsyncNotifier<List<String>> {
  static const _key = 'feast.recent_searches.v1';
  static const _max = 10;

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final current = state.valueOrNull ?? const <String>[];
    final next = [q, ...current.where((e) => e != q)].take(_max).toList();
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next);
  }

  Future<void> remove(String query) async {
    final current = state.valueOrNull ?? const <String>[];
    final next = current.where((e) => e != query).toList();
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next);
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesController, List<String>>(
  RecentSearchesController.new,
);
