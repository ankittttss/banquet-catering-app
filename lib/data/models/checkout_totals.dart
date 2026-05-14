import 'cart_item.dart';
import 'charges_config.dart';
import 'venue_type.dart';

/// Immutable value object for the full checkout breakdown.
/// Computed client-side from the cart + charges config before placing the order.
class CheckoutTotals {
  const CheckoutTotals({
    required this.foodCost,
    required this.banquetCharge,
    required this.deliveryCharge,
    required this.buffetSetup,
    required this.serviceBoyCost,
    required this.serviceBoyCount,
    required this.serviceBoyUnitCost,
    required this.waterBottleCost,
    required this.setupEquipment,
    required this.platformFee,
    required this.subtotal,
    required this.gst,
    required this.serviceTax,
    required this.total,
  });

  final double foodCost;
  final double banquetCharge;
  final double deliveryCharge;
  final double buffetSetup;
  /// Per-unit service boy charge (charges.serviceBoyCost).
  final double serviceBoyUnitCost;
  /// Customer-chosen number of service boys.
  final int serviceBoyCount;
  /// Total service-boy line: unit × count.
  final double serviceBoyCost;
  final double waterBottleCost;
  /// Total rupees from the customer's Setup & equipment selection (tents,
  /// tables, gensets, etc.). Only non-zero on the private-property path —
  /// the Setup screen is gated behind that branch and the hall provides
  /// equivalent infrastructure on the hall path.
  final double setupEquipment;
  final double platformFee;
  final double subtotal;
  final double gst;
  final double serviceTax;
  final double total;

  /// Build totals from the current cart + charges config.
  ///
  /// [guestCount] scales the food cost (cart lines are per-guest under the
  /// banquet-catering semantic). Defaults to 1 so legacy callers that haven't
  /// been updated keep producing per-guest totals — they'll under-quote the
  /// real billable amount, but won't break the build.
  ///
  /// [serviceBoyCount] multiplies the per-boy cost. Defaults to 1.
  ///
  /// [includeServiceTax] is the customer-side opt-in toggle. The tile is
  /// always shown in the bill details so the customer sees the configured
  /// percentage, but when this is `false` the amount is zeroed and the
  /// total drops accordingly. Defaults to `true` so legacy call sites keep
  /// applying service tax.
  ///
  /// [venueType] gates venue-specific lines. Private-property events skip
  /// the banquet hall fee; banquet-hall events skip the rented Setup &
  /// equipment line (the hall provides those).
  ///
  /// [addonsTotal] is the running total from the Setup & equipment screen.
  /// Only billed on the private-property path.
  static CheckoutTotals compute({
    required List<CartItem> cart,
    required ChargesConfig charges,
    required Map<String, double> deliveryByRestaurant,
    int guestCount = 1,
    int serviceBoyCount = 1,
    bool includeServiceTax = true,
    VenueType? venueType,
    double addonsTotal = 0,
  }) {
    final scale = guestCount.clamp(1, 100000);
    final boys = serviceBoyCount.clamp(0, 999);
    final food =
        cart.fold<double>(0, (s, i) => s + i.billedLineTotal(scale));
    final delivery =
        deliveryByRestaurant.values.fold<double>(0, (s, d) => s + d);
    final serviceBoyTotal = charges.serviceBoyCost * boys;

    final isPrivate = venueType == VenueType.privateProperty;
    final banquet = isPrivate ? 0.0 : charges.banquetCharge;
    final setupEquip = isPrivate ? addonsTotal : 0.0;

    final subtotal = food +
        banquet +
        delivery +
        charges.buffetSetup +
        serviceBoyTotal +
        charges.waterBottleCost +
        setupEquip +
        charges.platformFee;
    final gst = subtotal * (charges.gstPercent / 100);
    final serviceTax = includeServiceTax
        ? subtotal * (charges.serviceTaxPercent / 100)
        : 0.0;
    final total = subtotal + gst + serviceTax;
    return CheckoutTotals(
      foodCost: food,
      banquetCharge: banquet,
      deliveryCharge: delivery,
      buffetSetup: charges.buffetSetup,
      serviceBoyUnitCost: charges.serviceBoyCost,
      serviceBoyCount: boys,
      serviceBoyCost: serviceBoyTotal,
      waterBottleCost: charges.waterBottleCost,
      setupEquipment: setupEquip,
      platformFee: charges.platformFee,
      subtotal: subtotal,
      gst: gst,
      serviceTax: serviceTax,
      total: total,
    );
  }
}
