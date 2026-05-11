/// Kinds of private space a customer can host an event at.
enum PropertyType {
  home('home', 'Home', 'home_filled'),
  farmhouse('farmhouse', 'Farmhouse', 'diamond'),
  terrace('terrace', 'Terrace', 'local_fire_department'),
  lawn('lawn', 'Lawn / Garden', 'water_drop'),
  societyHall('society_hall', 'Society hall', 'group'),
  office('office', 'Office', 'chat_bubble_outline');

  const PropertyType(this.dbValue, this.label, this.iconName);
  final String dbValue;
  final String label;
  final String iconName;
}

/// Customer-supplied details about a private property they want to host at.
/// Lives inside [EventDraft] — not persisted on its own.
class PrivatePropertyDraft {
  const PrivatePropertyDraft({
    this.type,
    this.addressLine1,
    this.landmark,
    this.cityPincode,
  });

  final PropertyType? type;
  final String? addressLine1;
  final String? landmark;
  final String? cityPincode;

  bool get isComplete =>
      type != null &&
      (addressLine1 != null && addressLine1!.trim().isNotEmpty) &&
      (cityPincode != null && cityPincode!.trim().isNotEmpty);

  /// Best-effort short label for the sticky save banner: "Behind ITC Maratha",
  /// falling back to the first address line, then to "Property saved".
  String get shortLabel {
    final l = landmark?.trim();
    if (l != null && l.isNotEmpty) {
      // Show the landmark portion before the comma if present, mirroring
      // the mockup's "Behind ITC Maratha" affordance.
      final comma = l.indexOf(',');
      return comma > 0 ? l.substring(0, comma) : l;
    }
    final a = addressLine1?.trim();
    if (a != null && a.isNotEmpty) return a;
    return 'Property saved';
  }

  PrivatePropertyDraft copyWith({
    PropertyType? type,
    String? addressLine1,
    String? landmark,
    String? cityPincode,
  }) =>
      PrivatePropertyDraft(
        type: type ?? this.type,
        addressLine1: addressLine1 ?? this.addressLine1,
        landmark: landmark ?? this.landmark,
        cityPincode: cityPincode ?? this.cityPincode,
      );
}
