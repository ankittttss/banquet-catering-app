/// Lifecycle of a restaurant in the catalog. Only `published` rows are
/// visible to customers; the DB keeps `is_active` in sync via trigger
/// (phase34) so all legacy `is_active` filters keep working.
enum RestaurantStatus {
  draft('draft'),
  published('published'),
  suspended('suspended'),
  archived('archived');

  const RestaurantStatus(this.dbValue);
  final String dbValue;

  /// Rows fetched through legacy paths (geo RPCs, stub seeds) may not carry
  /// a status column — they are customer-visible by definition, so default
  /// to published.
  static RestaurantStatus fromDb(String? value) =>
      RestaurantStatus.values.firstWhere(
        (s) => s.dbValue == value,
        orElse: () => RestaurantStatus.published,
      );

  String get label => switch (this) {
        draft => 'Draft',
        published => 'Live',
        suspended => 'Suspended',
        archived => 'Archived',
      };
}

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
    this.latitude,
    this.longitude,
    this.address,
    this.distanceKm,
    this.status = RestaurantStatus.published,
    this.coverImageUrl,
    this.publishedAt,
    this.archivedAt,
    this.updatedAt,
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

  /// Restaurant coordinates — populated once lat/lng has been set on the row.
  final double? latitude;
  final double? longitude;
  final String? address;

  /// Distance from a query origin (only populated when fetched via the
  /// `restaurants_near` RPC).
  final double? distanceKm;

  /// Lifecycle state. Customers only ever see [RestaurantStatus.published]
  /// rows; the other states exist for the admin console.
  final RestaurantStatus status;

  /// Wide hero image for the detail page. Optional — the publish gate only
  /// requires *one* of logo/cover to be present.
  final String? coverImageUrl;

  /// Stamped by the phase34 lifecycle trigger.
  final DateTime? publishedAt;
  final DateTime? archivedAt;
  final DateTime? updatedAt;

  String get deliveryEta {
    if (deliveryMinMinutes == null || deliveryMaxMinutes == null) return '';
    return '$deliveryMinMinutes–$deliveryMaxMinutes min';
  }

  factory Restaurant.fromMap(Map<String, dynamic> map) => Restaurant(
        id: map['id'] as String,
        name: map['name'] as String,
        logoUrl: map['logo_url'] as String?,
        deliveryCharge: (map['delivery_charge'] as num?)?.toDouble() ?? 0,
        isActive: (map['is_active'] as bool?) ?? true,
        pricePerPlate: (map['price_per_plate'] as num?)?.toDouble(),
        minGuests: (map['min_guests'] as num?)?.toInt(),
        deliveryMinMinutes: (map['delivery_min_minutes'] as num?)?.toInt(),
        deliveryMaxMinutes: (map['delivery_max_minutes'] as num?)?.toInt(),
        rating: (map['rating'] as num?)?.toDouble(),
        ratingsCount: (map['ratings_count'] as num?)?.toInt(),
        cuisinesDisplay: map['cuisines_display'] as String?,
        heroBgHex: map['hero_bg_hex'] as String?,
        heroEmoji: map['hero_emoji'] as String?,
        tag: map['tag'] as String?,
        isPureVeg: (map['is_pure_veg'] as bool?) ?? false,
        popularityScore: (map['popularity_score'] as num?)?.toInt() ?? 0,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        address: map['address'] as String?,
        distanceKm: (map['distance_km'] as num?)?.toDouble(),
        status: RestaurantStatus.fromDb(map['status'] as String?),
        coverImageUrl: map['cover_image_url'] as String?,
        publishedAt: map['published_at'] is String
            ? DateTime.tryParse(map['published_at'] as String)
            : null,
        archivedAt: map['archived_at'] is String
            ? DateTime.tryParse(map['archived_at'] as String)
            : null,
        updatedAt: map['updated_at'] is String
            ? DateTime.tryParse(map['updated_at'] as String)
            : null,
      );

  /// Field-preserving copy. Like the other models' copyWith, passing null
  /// keeps the existing value — used by the stub admin repository to mimic
  /// partial updates in memory.
  Restaurant copyWith({
    String? name,
    String? logoUrl,
    double? deliveryCharge,
    bool? isActive,
    double? pricePerPlate,
    int? minGuests,
    int? deliveryMinMinutes,
    int? deliveryMaxMinutes,
    double? rating,
    int? ratingsCount,
    String? cuisinesDisplay,
    String? heroBgHex,
    String? heroEmoji,
    String? tag,
    bool? isPureVeg,
    int? popularityScore,
    double? latitude,
    double? longitude,
    String? address,
    RestaurantStatus? status,
    String? coverImageUrl,
    DateTime? publishedAt,
    DateTime? archivedAt,
    DateTime? updatedAt,
  }) =>
      Restaurant(
        id: id,
        name: name ?? this.name,
        logoUrl: logoUrl ?? this.logoUrl,
        deliveryCharge: deliveryCharge ?? this.deliveryCharge,
        isActive: isActive ?? this.isActive,
        pricePerPlate: pricePerPlate ?? this.pricePerPlate,
        minGuests: minGuests ?? this.minGuests,
        deliveryMinMinutes: deliveryMinMinutes ?? this.deliveryMinMinutes,
        deliveryMaxMinutes: deliveryMaxMinutes ?? this.deliveryMaxMinutes,
        rating: rating ?? this.rating,
        ratingsCount: ratingsCount ?? this.ratingsCount,
        cuisinesDisplay: cuisinesDisplay ?? this.cuisinesDisplay,
        heroBgHex: heroBgHex ?? this.heroBgHex,
        heroEmoji: heroEmoji ?? this.heroEmoji,
        tag: tag ?? this.tag,
        isPureVeg: isPureVeg ?? this.isPureVeg,
        popularityScore: popularityScore ?? this.popularityScore,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        address: address ?? this.address,
        distanceKm: distanceKm,
        status: status ?? this.status,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        publishedAt: publishedAt ?? this.publishedAt,
        archivedAt: archivedAt ?? this.archivedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
