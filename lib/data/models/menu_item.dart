class MenuItem {
  const MenuItem({
    required this.id,
    required this.restaurantId,
    required this.categoryId,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.isVeg = true,
    this.isAvailable = true,
  });

  final String id;
  final String restaurantId;
  final String categoryId;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final bool isVeg;
  final bool isAvailable;

  factory MenuItem.fromMap(Map<String, dynamic> map) => MenuItem(
        id: map['id'] as String,
        restaurantId: map['restaurant_id'] as String,
        categoryId: map['category_id'] as String,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        description: map['description'] as String?,
        imageUrl: map['image_url'] as String?,
        isVeg: (map['is_veg'] as bool?) ?? true,
        isAvailable: (map['is_available'] as bool?) ?? true,
      );
}
