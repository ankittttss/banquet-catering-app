import 'menu_item.dart';

enum Portion {
  regular('Regular', 1.0),
  large('Large', 1.4),
  family('Family', 1.8);

  const Portion(this.label, this.multiplier);
  final String label;
  final double multiplier;
}

enum SpiceLevel {
  mild('Mild'),
  medium('Medium'),
  spicy('Spicy');

  const SpiceLevel(this.label);
  final String label;
}

/// One line in the cart. Two lines of the same dish with different portion/
/// spice are kept separate via [signature].
class CartItem {
  const CartItem({
    required this.item,
    this.qty = 1,
    this.portion = Portion.regular,
    this.spice = SpiceLevel.medium,
    this.notes = '',
  });

  final MenuItem item;
  final int qty;
  final Portion portion;
  final SpiceLevel spice;
  final String notes;

  /// Effective per-unit price after portion multiplier.
  double get unitPrice => item.price * portion.multiplier;

  double get lineTotal => unitPrice * qty;

  /// Composite key: same menu item with different customizations is a
  /// separate cart line.
  String get signature => '${item.id}|${portion.name}|${spice.name}|$notes';

  CartItem copyWith({
    int? qty,
    Portion? portion,
    SpiceLevel? spice,
    String? notes,
  }) =>
      CartItem(
        item: item,
        qty: qty ?? this.qty,
        portion: portion ?? this.portion,
        spice: spice ?? this.spice,
        notes: notes ?? this.notes,
      );
}
