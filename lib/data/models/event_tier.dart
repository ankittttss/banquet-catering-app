/// Budget tier for an event (Budget / Standard / Premium-style bands).
/// Drives the restaurant picker's budget filter.
class EventTier {
  const EventTier({
    required this.id,
    required this.code,
    required this.label,
    required this.perGuestMin,
    required this.perGuestMax,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String label;
  final String? description;
  final double perGuestMin;
  final double perGuestMax;
  final int sortOrder;
  final bool isActive;

  /// Midpoint, used when estimating a "price per plate" on summary screens.
  double get perGuestMid => (perGuestMin + perGuestMax) / 2;

  factory EventTier.fromMap(Map<String, dynamic> map) => EventTier(
        id: map['id'] as String,
        code: map['code'] as String,
        label: map['label'] as String,
        description: map['description'] as String?,
        perGuestMin: (map['per_guest_min'] as num).toDouble(),
        perGuestMax: (map['per_guest_max'] as num).toDouble(),
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        isActive: (map['is_active'] as bool?) ?? true,
      );
}

/// Static fallback used when the DB is unavailable (dev stub mode) or when
/// an async load is still pending. Values mirror the Phase 14 seed.
const fallbackEventTiers = <EventTier>[
  EventTier(
    id: 'budget',
    code: 'budget',
    label: 'Budget Bite',
    description: '1 starter + 1 main + 1 dessert',
    perGuestMin: 120,
    perGuestMax: 220,
    sortOrder: 1,
  ),
  EventTier(
    id: 'standard',
    code: 'standard',
    label: 'Classic Meal',
    description: '2 starters + 2 mains + 1 dessert',
    perGuestMin: 220,
    perGuestMax: 380,
    sortOrder: 2,
  ),
  EventTier(
    id: 'premium',
    code: 'premium',
    label: 'Premium Feast',
    description: '4 starters + 3 mains + 2 desserts + drinks',
    perGuestMin: 380,
    perGuestMax: 700,
    sortOrder: 3,
  ),
];
