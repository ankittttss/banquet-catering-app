import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/repositories/address_repository.dart';
import '../../data/repositories/banquet_repository.dart';
import '../../data/repositories/charges_repository.dart';
import '../../data/repositories/delivery_repository.dart';
import '../../data/repositories/event_tier_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/restaurant_ops_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/repositories/staffing_repository.dart';
import '../../data/repositories/stub/stub_address_repository.dart';
import '../../data/repositories/stub/stub_banquet_repository.dart';
import '../../data/repositories/stub/stub_charges_repository.dart';
import '../../data/repositories/stub/stub_delivery_repository.dart';
import '../../data/repositories/stub/stub_event_tier_repository.dart';
import '../../data/repositories/stub/stub_menu_repository.dart';
import '../../data/repositories/stub/stub_notification_repository.dart';
import '../../data/repositories/stub/stub_order_repository.dart';
import '../../data/repositories/stub/stub_profile_repository.dart';
import '../../data/repositories/stub/stub_restaurant_ops_repository.dart';
import '../../data/repositories/stub/stub_review_repository.dart';
import '../../data/repositories/stub/stub_staffing_repository.dart';
import '../../data/repositories/stub/stub_taxonomy_repository.dart';
import '../../data/repositories/supabase/supabase_address_repository.dart';
import '../../data/repositories/supabase/supabase_banquet_repository.dart';
import '../../data/repositories/supabase/supabase_charges_repository.dart';
import '../../data/repositories/supabase/supabase_delivery_repository.dart';
import '../../data/repositories/supabase/supabase_event_tier_repository.dart';
import '../../data/repositories/supabase/supabase_menu_repository.dart';
import '../../data/repositories/supabase/supabase_notification_repository.dart';
import '../../data/repositories/supabase/supabase_order_repository.dart';
import '../../data/repositories/supabase/supabase_profile_repository.dart';
import '../../data/repositories/supabase/supabase_restaurant_ops_repository.dart';
import '../../data/repositories/supabase/supabase_review_repository.dart';
import '../../data/repositories/supabase/supabase_staffing_repository.dart';
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

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => _pick<DeliveryRepository>(
    SupabaseDeliveryRepository(),
    StubDeliveryRepository(),
  ),
);

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => _pick<ReviewRepository>(
    SupabaseReviewRepository(),
    StubReviewRepository(),
  ),
);

final eventTierRepositoryProvider = Provider<EventTierRepository>(
  (ref) => _pick<EventTierRepository>(
    SupabaseEventTierRepository(),
    StubEventTierRepository(),
  ),
);

final banquetRepositoryProvider = Provider<BanquetRepository>(
  (ref) => _pick<BanquetRepository>(
    SupabaseBanquetRepository(),
    StubBanquetRepository(),
  ),
);

final staffingRepositoryProvider = Provider<StaffingRepository>(
  (ref) => _pick<StaffingRepository>(
    SupabaseStaffingRepository(),
    StubStaffingRepository(),
  ),
);

final restaurantOpsRepositoryProvider = Provider<RestaurantOpsRepository>(
  (ref) => _pick<RestaurantOpsRepository>(
    SupabaseRestaurantOpsRepository(),
    StubRestaurantOpsRepository(),
  ),
);
