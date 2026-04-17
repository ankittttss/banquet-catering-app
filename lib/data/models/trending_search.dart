/// A suggested chip on the Search screen.
/// Backed by `public.trending_searches` in Supabase.
class TrendingSearch {
  const TrendingSearch({
    required this.id,
    required this.label,
    this.emoji,
    this.sortOrder = 0,
  });

  final String id;
  final String label;
  final String? emoji;
  final int sortOrder;

  factory TrendingSearch.fromMap(Map<String, dynamic> map) => TrendingSearch(
        id: map['id'] as String,
        label: map['label'] as String,
        emoji: map['emoji'] as String?,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}
