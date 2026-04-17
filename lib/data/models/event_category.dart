/// The "What's the occasion?" tiles on home.
/// Backed by `public.event_categories` in Supabase.
class EventCategory {
  const EventCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.emoji,
    required this.iconName,
    required this.bgHex,
    required this.iconHex,
    required this.sortOrder,
    this.defaultGuestCount = 25,
    this.defaultSession = 'Dinner',
  });

  final String id;
  final String slug;
  final String name;
  final String emoji;
  final String iconName;
  final String bgHex;
  final String iconHex;
  final int sortOrder;
  final int defaultGuestCount;
  final String defaultSession;

  factory EventCategory.fromMap(Map<String, dynamic> map) => EventCategory(
        id: map['id'] as String,
        slug: map['slug'] as String,
        name: map['name'] as String,
        emoji: map['emoji'] as String? ?? '🎉',
        iconName: map['icon_name'] as String? ?? 'celebration',
        bgHex: map['bg_hex'] as String? ?? '#FFF1F2',
        iconHex: map['icon_hex'] as String? ?? '#E23744',
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        defaultGuestCount:
            (map['default_guest_count'] as num?)?.toInt() ?? 25,
        defaultSession: map['default_session'] as String? ?? 'Dinner',
      );
}
