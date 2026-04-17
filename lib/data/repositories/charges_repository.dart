import '../models/charges_config.dart';

abstract interface class ChargesRepository {
  Future<ChargesConfig> fetch();
  Future<void> update(ChargesConfig config);
}
