import '../../core/utils/geo.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/restaurant.dart';

/// Valid, usable map coordinates: present, numeric, inside real lat/lng bounds
/// and not the (0,0) "null island" sentinel that our geocoding paths emit when
/// a row has no pin. An event location that can't be pinned can't be verified,
/// so it is rejected rather than silently accepted.
bool hasUsableCoords(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  if (lat.isNaN || lng.isNaN) return false;
  if (lat == 0 && lng == 0) return false;
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

/// A proposed event location — NOT applied to the draft until the customer
/// confirms the impact preview. Coordinates are REQUIRED and validated: a
/// candidate that cannot be pinned is rejected at construction ([tryCreate]),
/// because without a pin we cannot verify that any kitchen can serve it.
class LocationCandidate {
  const LocationCandidate({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;

  /// Returns null when the pick has no usable address or pin — callers must
  /// surface "we couldn't pin that address" and change nothing.
  static LocationCandidate? tryCreate({
    required String address,
    required double? latitude,
    required double? longitude,
  }) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;
    if (!hasUsableCoords(latitude, longitude)) return null;
    return LocationCandidate(
      address: trimmed,
      latitude: latitude!,
      longitude: longitude!,
    );
  }
}

/// Why a cart line cannot survive the move.
enum CartLineRemovalReason {
  /// Beyond [kServiceRadiusKm] of the candidate location.
  outOfRange,

  /// The kitchen has no usable pin, so serviceability cannot be confirmed.
  unverifiableDistance,

  /// The restaurant is suspended/archived/deleted since the item was added.
  restaurantInactive,

  /// The dish itself was turned off or deleted.
  itemUnavailable,
}

/// One cart LINE that will be removed, with enough detail to tell two
/// customised versions of the same dish apart.
class RemovedCartLine {
  const RemovedCartLine({
    required this.signature,
    required this.dishName,
    required this.restaurantName,
    required this.qty,
    required this.portion,
    required this.spice,
    required this.notes,
    required this.reason,
  });

  final String signature;
  final String dishName;
  final String restaurantName;

  /// Portions PER GUEST for this line (the cart bills qty × guests).
  final int qty;

  final String portion;
  final String spice;
  final String notes;
  final CartLineRemovalReason reason;

  /// "Large · Spicy · “no onion”" — what distinguishes this line from another
  /// line of the same dish. Empty when the line is entirely default.
  String get variant {
    final parts = <String>[
      if (portion.isNotEmpty && portion.toLowerCase() != 'regular') portion,
      if (spice.isNotEmpty && spice.toLowerCase() != 'medium') spice,
      if (notes.trim().isNotEmpty) '“${notes.trim()}”',
    ];
    return parts.join(' · ');
  }

  /// "Paneer Tikka (Large · “no onion”) from Kitchen A — 2 per guest —
  /// too far to deliver here". qty is portions PER GUEST, never a raw count.
  String get label {
    final v = variant;
    return '$dishName${v.isEmpty ? '' : ' ($v)'} from $restaurantName — '
        '$qty per guest — ${reasonText(reason)}';
  }

  static String reasonText(CartLineRemovalReason r) => switch (r) {
        CartLineRemovalReason.outOfRange => 'too far to deliver here',
        CartLineRemovalReason.unverifiableDistance =>
          'we can\'t confirm it delivers here',
        CartLineRemovalReason.restaurantInactive =>
          'this kitchen is no longer available',
        CartLineRemovalReason.itemUnavailable =>
          'this dish is no longer served',
      };
}

/// The transactional preview of changing the event location: exactly which
/// cart lines become invalid (and why), and which location-dependent
/// selections clear. Nothing here mutates state.
class LocationImpact {
  const LocationImpact({
    required this.removed,
    required this.keptLineCount,
    required this.venueWillClear,
    required this.propertyWillClear,
  });

  /// Every cart line that will be removed, with its reason.
  final List<RemovedCartLine> removed;

  /// How many cart lines survive the move.
  final int keptLineCount;

  /// A selected banquet venue will be unselected (it is the authoritative
  /// event location, so a location change abandons it).
  final bool venueWillClear;

  /// Private-property address details will be cleared (they described the old
  /// location); the property type survives.
  final bool propertyWillClear;

  List<String> get removedSignatures => [for (final r in removed) r.signature];
  int get removedLineCount => removed.length;
  bool get removesCartLines => removed.isNotEmpty;

  /// Whether applying changes anything beyond the address itself.
  bool get hasConsequences =>
      removesCartLines || venueWillClear || propertyWillClear;

  /// A no-op impact — nothing removed, nothing cleared.
  static const none = LocationImpact(
    removed: [],
    keptLineCount: 0,
    venueWillClear: false,
    propertyWillClear: false,
  );
}

/// Pure impact computation for a candidate at ([latitude], [longitude]).
///
/// A cart line is removed when ANY of these holds — matching the checkout
/// guard's blocking set plus the location rule:
///  • its restaurant is inactive / unresolvable ([inactiveRestaurantIds]);
///  • its dish is no longer orderable ([unavailableItemIds]);
///  • its restaurant is beyond [kServiceRadiusKm] of the candidate;
///  • its restaurant has no usable pin, so serviceability can't be confirmed.
///
/// The last rule is deliberate: an unverifiable kitchen must not be carried
/// into a confirmed event location on the assumption that it is fine.
LocationImpact computeLocationImpact({
  required double latitude,
  required double longitude,
  required List<CartItem> cart,
  required Map<String, Restaurant> cartRestaurants,
  required Set<String> inactiveRestaurantIds,
  required Set<String> unavailableItemIds,
  required bool venueWillClear,
  required bool propertyWillClear,
}) {
  final removed = <RemovedCartLine>[];
  var kept = 0;

  for (final line in cart) {
    final r = cartRestaurants[line.item.restaurantId];
    final name = r?.name ?? 'This kitchen';

    CartLineRemovalReason? reason;
    if (r == null ||
        inactiveRestaurantIds.contains(line.item.restaurantId) ||
        r.status != RestaurantStatus.published) {
      reason = CartLineRemovalReason.restaurantInactive;
    } else if (unavailableItemIds.contains(line.item.id)) {
      reason = CartLineRemovalReason.itemUnavailable;
    } else {
      switch (serviceabilityOf(
        r,
        customerLat: latitude,
        customerLng: longitude,
      )) {
        case Serviceability.outOfRange:
          reason = CartLineRemovalReason.outOfRange;
        case Serviceability.unknown:
          reason = CartLineRemovalReason.unverifiableDistance;
        case Serviceability.inRange:
          reason = null;
      }
    }

    if (reason == null) {
      kept++;
    } else {
      removed.add(
        RemovedCartLine(
          signature: line.signature,
          dishName: line.item.name,
          restaurantName: name,
          qty: line.qty,
          portion: line.portion.label,
          spice: line.spice.label,
          notes: line.notes,
          reason: reason,
        ),
      );
    }
  }

  return LocationImpact(
    removed: removed,
    keptLineCount: kept,
    venueWillClear: venueWillClear,
    propertyWillClear: propertyWillClear,
  );
}
