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
  static const cart = '/user/cart';
  static const checkout = '/user/checkout';
  static const orderSuccess = '/user/order-success';
  static const myEvents = '/user/events';
  static const orderDetail = '/user/events/:id'; // template

  // Admin
  static const adminHome = '/admin';
  static const adminOrders = '/admin/orders';
  static const adminMenu = '/admin/menu';
  static const adminCharges = '/admin/charges';

  static String orderDetailFor(String id) => '/user/events/$id';
}
