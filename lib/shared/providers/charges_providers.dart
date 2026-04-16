import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/charges_config.dart';
import 'repositories_providers.dart';

final chargesConfigProvider = FutureProvider<ChargesConfig>((ref) {
  return ref.read(chargesRepositoryProvider).fetch();
});
