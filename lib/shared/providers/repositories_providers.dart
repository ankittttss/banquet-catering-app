import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/repositories/address_repository.dart';
import '../../data/repositories/charges_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/stub/stub_address_repository.dart';
import '../../data/repositories/stub/stub_charges_repository.dart';
import '../../data/repositories/stub/stub_menu_repository.dart';
import '../../data/repositories/stub/stub_notification_repository.dart';
import '../../data/repositories/stub/stub_order_repository.dart';
import '../../data/repositories/stub/stub_profile_repository.dart';
import '../../data/repositories/stub/stub_taxonomy_repository.dart';
import '../../data/repositories/supabase/supabase_address_repository.dart';
import '../../data/repositories/supabase/supabase_charges_repository.dart';
import '../../data/repositories/supabase/supabase_menu_repository.dart';
import '../../data/repositories/supabase/supabase_notification_repository.dart';
import '../../data/repositories/supabase/supabase_order_repository.dart';
import '../../data/repositories/supabase/supabase_profile_repository.dart';
import '../../data/repositories/supabase/supabase_taxonomy_repository.dart';
import '../../data/repositories/taxonomy_repository.dart';

/// Selects the Supabase implementation when the app is configured with
/// credentials, otherwise falls back to in-memory stubs so the app remains
/// runnable for UI development. Keep this the only place that branches on
/// [AppConfig.hasSupabase] — all feature code should depend on the interfaces.
T _pick<T>(T supabase, T stub) =>
    AppConfig.hasSupabase ? supabase : stub;

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => _pick<MenuRepository>(
    SupabaseMenuRepository(),
    StubMenuRepository(),
  ),
);

final chargesRepositoryProvider = Provider<ChargesRepository>(
  (ref) => _pick<ChargesRepository>(
    SupabaseChargesRepository(),
    StubChargesRepository(),
  ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => _pick<ProfileRepository>(
    SupabaseProfileRepository(),
    StubProfileRepository(),
  ),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => _pick<OrderRepository>(
    SupabaseOrderRepository(),
    StubOrderRepository(),
  ),
);

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => _pick<AddressRepository>(
    SupabaseAddressRepository(),
    StubAddressRepository(),
  ),
);

final taxonomyRepositoryProvider = Provider<TaxonomyRepository>(
  (ref) => _pick<TaxonomyRepository>(
    SupabaseTaxonomyRepository(),
    StubTaxonomyRepository(),
  ),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => _pick<NotificationRepository>(
    SupabaseNotificationRepository(),
    StubNotificationRepository(),
  ),
);
