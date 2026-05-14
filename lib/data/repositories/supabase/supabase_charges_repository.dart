import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../models/charges_config.dart';
import '../charges_repository.dart';

class SupabaseChargesRepository implements ChargesRepository {
  @override
  Future<ChargesConfig> fetch() async {
    // Charges drive the bill breakdown — but they're also the *least*
    // critical bit of the cart screen. A flaky CORS preflight, a paused
    // project, or a missing row should never block the user from
    // reviewing their items. We log the cause for debugging and fall
    // back to the sensible defaults baked into the model so the cart
    // still renders a usable bill.
    try {
      final row = await supabase
          .from('charges_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return ChargesConfig.fallback;
      return ChargesConfig.fromMap(row);
    } catch (e, st) {
      debugPrint('charges_config fetch failed, using fallback: $e\n$st');
      return ChargesConfig.fallback;
    }
  }

  @override
  Future<void> update(ChargesConfig config) async {
    await supabase.from('charges_config').update({
      'banquet_charge': config.banquetCharge,
      'buffet_setup': config.buffetSetup,
      'service_boy_cost': config.serviceBoyCost,
      'water_bottle_cost': config.waterBottleCost,
      'platform_fee': config.platformFee,
      'gst_percent': config.gstPercent,
      'service_tax_percent': config.serviceTaxPercent,
    }).eq('id', 1);
  }
}
