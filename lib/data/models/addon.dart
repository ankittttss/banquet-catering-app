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

/// Pre-built collection of add-ons the customer can apply in one tap.
class AddonBundle {
  const AddonBundle({
    required this.id,
    required this.name,
    required this.description,
    required this.tintHex,
    required this.colorHex,
    required this.quantities,
  });

  final String id;
  final String name;
  final String description;
  final String tintHex;
  final String colorHex;
  /// Addon id → quantity to apply when this bundle is selected.
  final Map<String, int> quantities;
}
