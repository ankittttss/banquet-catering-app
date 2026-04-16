class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    this.logoUrl,
    this.deliveryCharge = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final double deliveryCharge;
  final bool isActive;

  factory Restaurant.fromMap(Map<String, dynamic> map) => Restaurant(
        id: map['id'] as String,
        name: map['name'] as String,
        logoUrl: map['logo_url'] as String?,
        deliveryCharge:
            (map['delivery_charge'] as num?)?.toDouble() ?? 0,
        isActive: (map['is_active'] as bool?) ?? true,
      );
}
