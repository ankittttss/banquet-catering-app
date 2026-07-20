/// A purchasable add-on the customer can rent for a private-property event.
class Addon {
  const Addon({
    required this.id,
    required this.group,
    required this.label,
    required this.subtitle,
    required this.iconName,
    required this.iconBgHex,
    required this.iconHex,
    required this.unitPrice,
    required this.unitLabel,
    required this.defaultQty,
    this.recommended = false,
  });

  final String id;

  /// "SHELTER & SEATING", "KITCHEN & EQUIPMENT", etc.
  final String group;
  final String label;
  final String subtitle;
  final String iconName;
  final String iconBgHex;
  final String iconHex;
  final double unitPrice;

  /// Trailing word on the price ("unit", "chair", "table"). Rendered as
  /// "₹X / {unitLabel}" in the row.
  final String unitLabel;
  final int defaultQty;
  final bool recommended;
}
