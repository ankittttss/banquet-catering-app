class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    this.logoUrl,
    this.deliveryCharge = 0,
    this.isActive = true,
    this.pricePerPlate,
    this.minGuests,
    this.deliveryMinMinutes,
    this.deliveryMaxMinutes,
    this.rating,
    this.ratingsCount,
    this.cuisinesDisplay,
    this.heroBgHex,
    this.heroEmoji,
    this.tag,
    this.isPureVeg = false,
    this.popularityScore = 0,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final double deliveryCharge;
  final bool isActive;

  /// Per-plate price (₹). Drives the card's price chip.
  final double? pricePerPlate;

  /// Minimum booking size — "Min 5 guests" badge on the card.
  final int? minGuests;

  /// Delivery ETA window — displayed as "30–40 min".
  final int? deliveryMinMinutes;
  final int? deliveryMaxMinutes;

  /// 1-decimal rating (e.g. 4.5). Rendered in the green chip.
  final double? rating;
  final int? ratingsCount;

  /// Human string: "North Indian · Mughlai".
  final String? cuisinesDisplay;

  /// Background color for the hero image area (hex, e.g. "#FFF3E0").
  final String? heroBgHex;

  /// Big emoji shown when logoUrl is missing or fails to load.
  final String? heroEmoji;

  /// Corner tag like "Bestseller" / "Event Special".
  final String? tag;
  final bool isPureVeg;
  final int popularityScore;

  String get deliveryEta {
    if (deliveryMinMinutes == null || deliveryMaxMinutes == null) return '';
    return '$deliveryMinMinutes–$deliveryMaxMinutes min';
  }

  factory Restaurant.fromMap(Map<String, dynamic> map) => Restaurant(
        id: map['id'] as String,
        name: map['name'] as String,
        logoUrl: map['logo_url'] as String?,
        deliveryCharge:
            (map['delivery_charge'] as num?)?.toDouble() ?? 0,
        isActive: (map['is_active'] as bool?) ?? true,
        pricePerPlate: (map['price_per_plate'] as num?)?.toDouble(),
        minGuests: (map['min_guests'] as num?)?.toInt(),
        deliveryMinMinutes:
            (map['delivery_min_minutes'] as num?)?.toInt(),
        deliveryMaxMinutes:
            (map['delivery_max_minutes'] as num?)?.toInt(),
        rating: (map['rating'] as num?)?.toDouble(),
        ratingsCount: (map['ratings_count'] as num?)?.toInt(),
        cuisinesDisplay: map['cuisines_display'] as String?,
        heroBgHex: map['hero_bg_hex'] as String?,
        heroEmoji: map['hero_emoji'] as String?,
        tag: map['tag'] as String?,
        isPureVeg: (map['is_pure_veg'] as bool?) ?? false,
        popularityScore: (map['popularity_score'] as num?)?.toInt() ?? 0,
      );
}
