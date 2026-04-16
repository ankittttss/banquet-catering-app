import 'menu_item.dart';

class CartItem {
  const CartItem({required this.item, this.qty = 1});

  final MenuItem item;
  final int qty;

  double get lineTotal => item.price * qty;

  CartItem copyWith({int? qty}) => CartItem(item: item, qty: qty ?? this.qty);
}
