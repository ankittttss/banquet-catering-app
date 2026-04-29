/// Admin-controlled pricing constants used at checkout.
class ChargesConfig {
  const ChargesConfig({
    required this.banquetCharge,
    required this.buffetSetup,
    required this.serviceBoyCost,
    required this.waterBottleCost,
    required this.platformFee,
    required this.gstPercent,
    required this.serviceTaxPercent,
  });

  final double banquetCharge;
  final double buffetSetup;
  /// Per-service-boy cost — multiplied by the customer-chosen count.
  final double serviceBoyCost;
  final double waterBottleCost;
  final double platformFee;
  final double gstPercent;
  /// Service tax shown as a separate line on the bill, on top of GST.
  final double serviceTaxPercent;

  static const ChargesConfig fallback = ChargesConfig(
    banquetCharge: 0,
    buffetSetup: 0,
    serviceBoyCost: 0,
    waterBottleCost: 0,
    platformFee: 0,
    gstPercent: 5,
    serviceTaxPercent: 5,
  );

  factory ChargesConfig.fromMap(Map<String, dynamic> map) => ChargesConfig(
        banquetCharge:
            (map['banquet_charge'] as num?)?.toDouble() ?? 0,
        buffetSetup: (map['buffet_setup'] as num?)?.toDouble() ?? 0,
        serviceBoyCost:
            (map['service_boy_cost'] as num?)?.toDouble() ?? 0,
        waterBottleCost:
            (map['water_bottle_cost'] as num?)?.toDouble() ?? 0,
        platformFee: (map['platform_fee'] as num?)?.toDouble() ?? 0,
        gstPercent: (map['gst_percent'] as num?)?.toDouble() ?? 5,
        serviceTaxPercent:
            (map['service_tax_percent'] as num?)?.toDouble() ?? 5,
      );
}
