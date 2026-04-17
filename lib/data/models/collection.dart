/// A "Curated for events" horizontal-scroll tile.
/// Backed by `public.collections` in Supabase.
class Collection {
  const Collection({
    required this.id,
    required this.slug,
    required this.name,
    required this.emoji,
    required this.iconName,
    required this.bgHex,
    required this.iconHex,
    required this.sortOrder,
    this.subtitle,
  });

  final String id;
  final String slug;
  final String name;
  final String? subtitle;
  final String emoji;
  final String iconName;
  final String bgHex;
  final String iconHex;
  final int sortOrder;

  factory Collection.fromMap(Map<String, dynamic> map) => Collection(
        id: map['id'] as String,
        slug: map['slug'] as String,
        name: map['name'] as String,
        subtitle: map['subtitle'] as String?,
        emoji: map['emoji'] as String? ?? '🍽️',
        iconName: map['icon_name'] as String? ?? 'restaurant',
        bgHex: map['bg_hex'] as String? ?? '#FFF1F2',
        iconHex: map['icon_hex'] as String? ?? '#E23744',
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}
