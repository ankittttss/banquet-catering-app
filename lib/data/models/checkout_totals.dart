import 'cart_item.dart';
import 'charges_config.dart';

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
  static CheckoutTotals compute({
    required List<CartItem> cart,
    required ChargesConfig charges,
    required Map<String, double> deliveryByRestaurant,
    int guestCount = 1,
    int serviceBoyCount = 1,
  }) {
    final scale = guestCount.clamp(1, 100000);
    final boys = serviceBoyCount.clamp(0, 999);
    final food =
        cart.fold<double>(0, (s, i) => s + i.billedLineTotal(scale));
    final delivery =
        deliveryByRestaurant.values.fold<double>(0, (s, d) => s + d);
    final serviceBoyTotal = charges.serviceBoyCost * boys;
    final subtotal = food +
        charges.banquetCharge +
        delivery +
        charges.buffetSetup +
        serviceBoyTotal +
        charges.waterBottleCost +
        charges.platformFee;
    final gst = subtotal * (charges.gstPercent / 100);
    final serviceTax = subtotal * (charges.serviceTaxPercent / 100);
    final total = subtotal + gst + serviceTax;
    return CheckoutTotals(
      foodCost: food,
      banquetCharge: charges.banquetCharge,
      deliveryCharge: delivery,
      buffetSetup: charges.buffetSetup,
      serviceBoyUnitCost: charges.serviceBoyCost,
      serviceBoyCount: boys,
      serviceBoyCost: serviceBoyTotal,
      waterBottleCost: charges.waterBottleCost,
      platformFee: charges.platformFee,
      subtotal: subtotal,
      gst: gst,
      serviceTax: serviceTax,
      total: total,
    );
  }
}
