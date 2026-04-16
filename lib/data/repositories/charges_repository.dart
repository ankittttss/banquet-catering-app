import '../../core/config/app_config.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/charges_config.dart';

class ChargesRepository {
  ChargesRepository();

  Future<ChargesConfig> fetch() async {
    if (!AppConfig.hasSupabase) return _stub;
    final row = await supabase
        .from('charges_config')
        .select()
        .eq('id', 1)
        .maybeSingle();
    if (row == null) return ChargesConfig.fallback;
    return ChargesConfig.fromMap(row);
  }

  Future<void> update(ChargesConfig config) async {
    if (!AppConfig.hasSupabase) return;
    await supabase.from('charges_config').update({
      'banquet_charge': config.banquetCharge,
      'buffet_setup': config.buffetSetup,
      'service_boy_cost': config.serviceBoyCost,
      'water_bottle_cost': config.waterBottleCost,
      'platform_fee': config.platformFee,
      'gst_percent': config.gstPercent,
    }).eq('id', 1);
  }

  static const _stub = ChargesConfig(
    banquetCharge: 8000,
    buffetSetup: 2500,
    serviceBoyCost: 3500,
    waterBottleCost: 1000,
    platformFee: 149,
    gstPercent: 5,
  );
}
