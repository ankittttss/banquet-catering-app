import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/user_profile.dart';
import '../../data/models/user_role.dart';
import '../../features/admin/screens/admin_charges_screen.dart';
import '../../features/admin/screens/admin_home_screen.dart';
import '../../features/admin/screens/admin_menu_screen.dart';
import '../../features/admin/screens/admin_orders_screen.dart';
import '../../features/admin/screens/admin_partners_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/banquet/screens/banquet_home_screen.dart';
import '../../features/banquet/screens/banquet_inbox_screen.dart';
import '../../features/banquet/screens/banquet_inventory_screen.dart';
import '../../features/banquet/screens/banquet_venues_screen.dart';
import '../../features/delivery/screens/active_delivery_screen.dart';
import '../../features/delivery/screens/delivery_completed_screen.dart';
import '../../features/delivery/screens/delivery_earnings_screen.dart';
import '../../features/delivery/screens/delivery_history_screen.dart';
import '../../features/delivery/screens/delivery_home_screen.dart';
import '../../features/delivery/screens/delivery_otp_screen.dart';
import '../../features/delivery/screens/delivery_profile_screen.dart';
import '../../features/delivery/screens/pickup_checklist_screen.dart';
import '../../features/manager/screens/manager_home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/restaurant/screens/restaurant_home_screen.dart';
import '../../features/service_boy/screens/service_boy_home_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/user/screens/about_screen.dart';
import '../../features/user/screens/addresses_screen.dart';
import '../../features/user/screens/cart_screen.dart';
import '../../features/user/screens/checkout_screen.dart';
import '../../features/user/screens/edit_profile_screen.dart';
import '../../features/user/screens/event_details_screen.dart';
import '../../features/user/screens/favorites_screen.dart';
import '../../features/user/screens/help_support_screen.dart';
import '../../features/user/screens/menu_screen.dart';
import '../../features/user/screens/my_events_screen.dart';
import '../../features/user/screens/notifications_screen.dart';
import '../../features/user/screens/order_detail_screen.dart';
import '../../features/user/screens/order_success_screen.dart';
import '../../features/user/screens/profile_screen.dart';
import '../../features/user/screens/restaurant_detail_screen.dart';
import '../../features/user/screens/search_screen.dart';
import '../../features/user/screens/user_home_screen.dart';
import '../../shared/providers/auth_providers.dart';
import '../config/app_config.dart';
import '../supabase/supabase_client.dart' as sb;
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // React to auth state so the router re-evaluates redirects.
  final authChanges = ref.watch(authStateChangesProvider);

  // Snapshot the profile as-is (not just the role) so the redirect callback
  // can tell "still loading" from "resolved as customer". Without this, an
  // admin would get bounced to /user while their profile is mid-load.
  var profileAsync =
      const AsyncValue<UserProfile?>.loading();
  ref.listen(
    currentProfileProvider,
    (_, next) {
      profileAsync = next;
    },
    fireImmediately: true,
  );

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _RouterRefresh(authChanges),
    redirect: (context, state) {
      final loggedIn =
          AppConfig.hasSupabase && sb.auth.currentUser != null;

      final loc = state.matchedLocation;
      final isAuthRoute =
          loc == AppRoutes.login || loc == AppRoutes.otp;
      final isSplash = loc == AppRoutes.splash;
      final isOnboarding = loc == AppRoutes.onboarding;

      // Let splash + onboarding show freely.
      if (isSplash || isOnboarding) return null;

      // Not signed in → force to login (unless Supabase isn't configured, in
      // which case we let devs roam freely for UI work).
      if (!loggedIn && AppConfig.hasSupabase && !isAuthRoute) {
        return AppRoutes.login;
      }

      // Dev mode (no Supabase): let devs roam freely across roles for UI work.
      if (!AppConfig.hasSupabase) return null;

      // Profile not resolved yet — don't make a routing decision based on a
      // stale default role. Splash is already showing; keep the current
      // location until the listener updates.
      if (loggedIn && profileAsync.isLoading) return null;

      final role = profileAsync.valueOrNull?.role ?? UserRole.customer;

      // Signed in and landing on an auth route → bounce to home.
      if (loggedIn && isAuthRoute) {
        return _homeFor(role);
      }

      // Per-prefix role gates. Each operator role can only reach its own
      // prefix; everyone else gets bounced to their home.
      final gates = <String, UserRole>{
        '/admin': UserRole.admin,
        '/banquet': UserRole.banquet,
        '/restaurant': UserRole.restaurant,
        '/manager': UserRole.manager,
        '/service-boy': UserRole.serviceBoy,
        // Legacy delivery routes kept in the app for now — admin-only while
        // we migrate; Phase 17 will remove these screens entirely.
        '/delivery': UserRole.admin,
      };
      for (final entry in gates.entries) {
        if (loc.startsWith(entry.key) && role != entry.value) {
          return _homeFor(role);
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (_, s) => _page(s, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (_, s) => _page(s, const OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, s) => _page(s, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.otp,
        pageBuilder: (_, s) {
          final phone = s.uri.queryParameters['phone'] ?? '';
          return _page(s, OtpScreen(phone: phone));
        },
      ),
      GoRoute(
        path: AppRoutes.userHome,
        pageBuilder: (_, s) => _page(s, const UserHomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (_, s) => _page(s, const ProfileScreen()),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        pageBuilder: (_, s) => _page(s, const EditProfileScreen()),
      ),
      GoRoute(
        path: AppRoutes.addresses,
        pageBuilder: (_, s) => _page(s, const AddressesScreen()),
      ),
      GoRoute(
        path: AppRoutes.eventDetails,
        pageBuilder: (_, s) => _page(s, const EventDetailsScreen()),
      ),
      GoRoute(
        path: AppRoutes.menu,
        pageBuilder: (_, s) => _page(s, const MenuScreen()),
      ),
      GoRoute(
        path: AppRoutes.restaurantDetail,
        pageBuilder: (_, s) => _page(
          s,
          RestaurantDetailScreen(
              restaurantId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.search,
        pageBuilder: (_, s) => _page(s, const SearchScreen()),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        pageBuilder: (_, s) => _page(s, const FavoritesScreen()),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (_, s) => _page(s, const NotificationsScreen()),
      ),
      GoRoute(
        path: AppRoutes.cart,
        pageBuilder: (_, s) => _page(s, const CartScreen()),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        pageBuilder: (_, s) => _page(s, const CheckoutScreen()),
      ),
      GoRoute(
        path: AppRoutes.orderSuccess,
        pageBuilder: (_, s) {
          final id = s.uri.queryParameters['id'] ?? '';
          return _page(s, OrderSuccessScreen(orderId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.myEvents,
        pageBuilder: (_, s) => _page(s, const MyEventsScreen()),
      ),
      GoRoute(
        path: AppRoutes.orderDetail,
        pageBuilder: (_, s) => _page(
          s,
          OrderDetailScreen(orderId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.about,
        pageBuilder: (_, s) => _page(s, const AboutScreen()),
      ),
      GoRoute(
        path: AppRoutes.helpSupport,
        pageBuilder: (_, s) => _page(s, const HelpSupportScreen()),
      ),
      GoRoute(
        path: AppRoutes.adminHome,
        pageBuilder: (_, s) => _page(s, const AdminHomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.adminOrders,
        pageBuilder: (_, s) => _page(s, const AdminOrdersScreen()),
      ),
      GoRoute(
        path: AppRoutes.adminMenu,
        pageBuilder: (_, s) => _page(s, const AdminMenuScreen()),
      ),
      GoRoute(
        path: AppRoutes.adminCharges,
        pageBuilder: (_, s) => _page(s, const AdminChargesScreen()),
      ),
      GoRoute(
        path: AppRoutes.adminPartners,
        pageBuilder: (_, s) => _page(s, const AdminPartnersScreen()),
      ),
      GoRoute(
        path: AppRoutes.banquetHome,
        pageBuilder: (_, s) => _page(s, const BanquetHomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.banquetInbox,
        pageBuilder: (_, s) {
          final filter = s.uri.queryParameters['filter'];
          return _page(s, BanquetInboxScreen(initialFilter: filter));
        },
      ),
      GoRoute(
        path: AppRoutes.banquetVenues,
        pageBuilder: (_, s) => _page(s, const BanquetVenuesScreen()),
      ),
      GoRoute(
        path: AppRoutes.banquetInventory,
        pageBuilder: (_, s) => _page(s, const BanquetInventoryScreen()),
      ),
      GoRoute(
        path: AppRoutes.restaurantHome,
        pageBuilder: (_, s) => _page(s, const RestaurantHomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.managerHome,
        pageBuilder: (_, s) => _page(s, const ManagerHomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.serviceBoyHome,
        pageBuilder: (_, s) => _page(s, const ServiceBoyHomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.deliveryHome,
        pageBuilder: (_, s) => _page(s, const DeliveryHomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.deliveryActive,
        pageBuilder: (_, s) => _page(
          s,
          ActiveDeliveryScreen(assignmentId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.deliveryPickup,
        pageBuilder: (_, s) => _page(
          s,
          PickupChecklistScreen(assignmentId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.deliveryDeliver,
        pageBuilder: (_, s) => _page(
          s,
          DeliveryOtpScreen(assignmentId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.deliveryCompleted,
        pageBuilder: (_, s) => _page(
          s,
          DeliveryCompletedScreen(assignmentId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.deliveryEarnings,
        pageBuilder: (_, s) => _page(s, const DeliveryEarningsScreen()),
      ),
      GoRoute(
        path: AppRoutes.deliveryHistory,
        pageBuilder: (_, s) => _page(s, const DeliveryHistoryScreen()),
      ),
      GoRoute(
        path: AppRoutes.deliveryProfile,
        pageBuilder: (_, s) => _page(s, const DeliveryProfileScreen()),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.matchedLocation}')),
    ),
  );
});

String _homeFor(UserRole role) => switch (role) {
      UserRole.admin => AppRoutes.adminHome,
      UserRole.banquet => AppRoutes.banquetHome,
      UserRole.restaurant => AppRoutes.restaurantHome,
      UserRole.manager => AppRoutes.managerHome,
      UserRole.serviceBoy => AppRoutes.serviceBoyHome,
      UserRole.customer => AppRoutes.userHome,
    };

CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(AsyncValue<dynamic> authChanges) {
    // Notify on every auth state tick.
    authChanges.whenOrNull(data: (_) => notifyListeners());
  }
}
