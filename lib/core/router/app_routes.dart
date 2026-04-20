class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const otp = '/otp';

  // User
  static const userHome = '/user';
  static const profile = '/user/profile';
  static const editProfile = '/user/profile/edit';
  static const addresses = '/user/addresses';
  static const eventDetails = '/user/event';
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

  // Admin
  static const adminHome = '/admin';
  static const adminOrders = '/admin/orders';
  static const adminMenu = '/admin/menu';
  static const adminCharges = '/admin/charges';
  static const adminPartners = '/admin/partners';

  // Delivery partner
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
