import '../../../core/supabase/supabase_client.dart';
import '../../models/charges_config.dart';
import '../charges_repository.dart';

class SupabaseChargesRepository implements ChargesRepository {
  @override
  Future<ChargesConfig> fetch() async {
    final row = await supabase
        .from('charges_config')
        .select()
        .eq('id', 1)
        .maybeSingle();
    if (row == null) return ChargesConfig.fallback;
    return ChargesConfig.fromMap(row);
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
    }).eq('id', 1);
  }
}
