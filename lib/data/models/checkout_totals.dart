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
    required this.waterBottleCost,
    required this.platformFee,
    required this.subtotal,
    required this.gst,
    required this.total,
  });

  final double foodCost;
  final double banquetCharge;
  final double deliveryCharge;
  final double buffetSetup;
  final double serviceBoyCost;
  final double waterBottleCost;
  final double platformFee;
  final double subtotal;
  final double gst;
  final double total;

  static CheckoutTotals compute({
    required List<CartItem> cart,
    required ChargesConfig charges,
    required Map<String, double> deliveryByRestaurant,
  }) {
    final food = cart.fold<double>(0, (s, i) => s + i.lineTotal);
    final delivery =
        deliveryByRestaurant.values.fold<double>(0, (s, d) => s + d);
    final subtotal = food +
        charges.banquetCharge +
        delivery +
        charges.buffetSetup +
        charges.serviceBoyCost +
        charges.waterBottleCost +
        charges.platformFee;
    final gst = subtotal * (charges.gstPercent / 100);
    final total = subtotal + gst;
    return CheckoutTotals(
      foodCost: food,
      banquetCharge: charges.banquetCharge,
      deliveryCharge: delivery,
      buffetSetup: charges.buffetSetup,
      serviceBoyCost: charges.serviceBoyCost,
      waterBottleCost: charges.waterBottleCost,
      platformFee: charges.platformFee,
      subtotal: subtotal,
      gst: gst,
      total: total,
    );
  }
}
