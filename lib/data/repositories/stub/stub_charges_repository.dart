import '../../models/charges_config.dart';
import '../charges_repository.dart';

class StubChargesRepository implements ChargesRepository {
  ChargesConfig _state = const ChargesConfig(
    banquetCharge: 8000,
    buffetSetup: 2500,
    serviceBoyCost: 800,
    waterBottleCost: 1000,
    platformFee: 149,
    gstPercent: 5,
    serviceTaxPercent: 5,
  );

  @override
  Future<ChargesConfig> fetch() async => _state;

  @override
  Future<void> update(ChargesConfig config) async => _state = config;
}
