/// A promo card on the restaurant detail page.
/// Backed by `public.restaurant_offers` in Supabase.
class RestaurantOffer {
  const RestaurantOffer({
    required this.id,
    required this.restaurantId,
    required this.title,
    this.subtitle,
    this.code,
    this.accentHex,
    this.bgHex,
    this.sortOrder = 0,
  });

  final String id;
  final String restaurantId;
  final String title;
  final String? subtitle;
  final String? code;
  final String? accentHex;
  final String? bgHex;
  final int sortOrder;

  factory RestaurantOffer.fromMap(Map<String, dynamic> map) => RestaurantOffer(
        id: map['id'] as String,
        restaurantId: map['restaurant_id'] as String,
        title: map['title'] as String,
        subtitle: map['subtitle'] as String?,
        code: map['code'] as String?,
        accentHex: map['accent_hex'] as String?,
        bgHex: map['bg_hex'] as String?,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}
