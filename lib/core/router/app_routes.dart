class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const otp = '/otp';

  // User
  static const userHome = '/user';
  static const profile = '/user/profile';
  static const addresses = '/user/addresses';
  static const eventDetails = '/user/event';
  static const menu = '/user/menu';
  static const restaurantDetail = '/user/restaurants/:id'; // template
  static const search = '/user/search';
  static const favorites = '/user/favorites';
  static const cart = '/user/cart';
  static const checkout = '/user/checkout';
  static const orderSuccess = '/user/order-success';
  static const myEvents = '/user/events';
  static const orderDetail = '/user/events/:id'; // template

  static String restaurantDetailFor(String id) => '/user/restaurants/$id';

  // Admin
  static const adminHome = '/admin';
  static const adminOrders = '/admin/orders';
  static const adminMenu = '/admin/menu';
  static const adminCharges = '/admin/charges';

  static String orderDetailFor(String id) => '/user/events/$id';
}
