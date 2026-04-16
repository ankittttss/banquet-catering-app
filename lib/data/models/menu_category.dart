class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int sortOrder;

  factory MenuCategory.fromMap(Map<String, dynamic> map) => MenuCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        sortOrder: (map['sort_order'] as num).toInt(),
      );
}
