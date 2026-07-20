class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const otp = '/otp';

  // Customer
  static const userHome = '/user';
  static const profile = '/user/profile';
  static const editProfile = '/user/profile/edit';
  static const addresses = '/user/addresses';
  static const eventDetails = '/user/event';
  static const eventVenueType = '/user/event/venue';
  static const eventProperty = '/user/event/property';
  static const eventSetup = '/user/event/setup';

  /// Read-only overview of the in-progress event. Edit actions land here in
  /// Phase 2; Phase 1 renders the plan and the "Plan an event" empty state.
  static const eventPlan = '/user/event/plan';
  static const menu = '/user/menu';
  static const restaurantDetail = '/user/restaurants/:id'; // template
  static const search = '/user/search';
  static const favorites = '/user/favorites';
  static const notifications = '/user/notifications';
  static const cart = '/user/cart';
  static const checkout = '/user/checkout';
  static const orderSuccess = '/user/order-success';
  static const myEvents = '/user/events';
  static const orderDetail = '/user/events/:id'; // template
  static const about = '/user/about';
  static const helpSupport = '/user/help';

  static String restaurantDetailFor(String id) => '/user/restaurants/$id';

  // Admin — deliberately small: onboard/manage restaurants + charges.
  // (Global orders manager, global menu editor and delivery partners were
  // retired; statuses flow automatically and menus are per-restaurant.)
  static const adminHome = '/admin';
  static const adminCharges = '/admin/charges';
  static const adminVenues = '/admin/venues';
  static const adminRestaurants = '/admin/restaurants';
  static const adminRestaurantNew = '/admin/restaurants/new';
  static const adminRestaurantDetail = '/admin/restaurants/:id'; // template
  static const adminRestaurantEdit = '/admin/restaurants/:id/edit'; // template

  static String adminRestaurantFor(String id) => '/admin/restaurants/$id';
  static String adminRestaurantEditFor(String id) =>
      '/admin/restaurants/$id/edit';

  // Banquet operator
  static const banquetHome = '/banquet';
  static const banquetInbox = '/banquet/inbox';
  static const banquetBookingDetail = '/banquet/inbox/:id'; // template
  static const banquetVenues = '/banquet/venues';
  static const banquetInventory = '/banquet/inventory';

  static String banquetBookingDetailFor(String id) => '/banquet/inbox/$id';

  // Restaurant operator
  static const restaurantHome = '/restaurant';

  // Manager
  static const managerHome = '/manager';
  static const managerEventDetail = '/manager/events/:id'; // template

  static String managerEventDetailFor(String id) => '/manager/events/$id';

  // Service boy
  static const serviceBoyHome = '/service-boy';

  // Legacy delivery routes — kept reachable only so existing deep links
  // don't crash; Phase 12 retired in-app dispatch so these screens are
  // gated to admins for now.
  static const deliveryHome = '/delivery';
  static const deliveryActive = '/delivery/active/:id'; // template
  static const deliveryPickup = '/delivery/pickup/:id'; // template
  static const deliveryDeliver = '/delivery/deliver/:id'; // template
  static const deliveryCompleted = '/delivery/completed/:id'; // template
  static const deliveryEarnings = '/delivery/earnings';
  static const deliveryHistory = '/delivery/history';
  static const deliveryProfile = '/delivery/profile';

  static String orderDetailFor(String id) => '/user/events/$id';
  static String deliveryActiveFor(String id) => '/delivery/active/$id';
  static String deliveryPickupFor(String id) => '/delivery/pickup/$id';
  static String deliveryDeliverFor(String id) => '/delivery/deliver/$id';
  static String deliveryCompletedFor(String id) => '/delivery/completed/$id';
}
