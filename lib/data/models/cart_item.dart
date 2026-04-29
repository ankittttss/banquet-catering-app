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
///
/// Banquet-catering semantic:
///   - `qty` is "portions per guest" (default 1 = one plate per guest)
///   - final billed quantity at checkout = `qty * event.guestCount`
///   - `unitPrice` stays per-plate; `lineTotal` (unscaled) represents a
///     single guest's share — checkout scales it by guest count.
class CartItem {
  const CartItem({
    required this.item,
    this.qty = 1,
    this.portion = Portion.regular,
    this.spice = SpiceLevel.medium,
    this.notes = '',
  });

  final MenuItem item;

  /// Portions per guest. Displayed as "N per guest" in the cart UI.
  final int qty;
  final Portion portion;
  final SpiceLevel spice;
  final String notes;

  /// Effective per-portion price after portion multiplier.
  double get unitPrice => item.price * portion.multiplier;

  /// Cost for one guest (qty portions × unit price). Multiply by the event's
  /// `guestCount` to get the billed line total. Kept unscaled so cart-level
  /// providers can tell whether a guest-count change affects totals.
  double get perGuestLineCost => unitPrice * qty;

  /// Legacy alias — treated as per-guest cost. Callers that want the final
  /// billable amount should use [billedLineTotal] with a guest count.
  double get lineTotal => perGuestLineCost;

  double billedLineTotal(int guestCount) => perGuestLineCost * guestCount;

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
