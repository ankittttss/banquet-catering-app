import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/repositories/address_repository.dart';
import '../../data/repositories/charges_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/stub/stub_address_repository.dart';
import '../../data/repositories/supabase/supabase_address_repository.dart';

final menuRepositoryProvider =
    Provider<MenuRepository>((ref) => MenuRepository());

final chargesRepositoryProvider =
    Provider<ChargesRepository>((ref) => ChargesRepository());

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository());

final orderRepositoryProvider =
    Provider<OrderRepository>((ref) => OrderRepository());

/// Picks Supabase impl when configured; falls back to stub for local UI dev.
final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AppConfig.hasSupabase
      ? SupabaseAddressRepository()
      : StubAddressRepository();
});
