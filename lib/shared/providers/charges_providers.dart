import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/charges_config.dart';
import 'repositories_providers.dart';

final chargesConfigProvider = FutureProvider<ChargesConfig>((ref) {
  return ref.read(chargesRepositoryProvider).fetch();
});

/// Customer-side opt-in for the service-tax line. Defaults to `true`.
/// Both cart and checkout screens read the same value so the choice
/// carries across the cart → checkout flow.
final includeServiceTaxProvider = StateProvider<bool>((_) => true);
