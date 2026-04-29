enum UserRole {
  customer('Customer', 'Plan events, pick menus, place bookings'),
  banquet('Banquet', 'Receive bookings, assign managers, track events'),
  restaurant('Restaurant', 'Accept vendor lots, update prep status'),
  manager('Manager', 'Run assigned events, staff service boys'),
  serviceBoy('Service Boy', 'Work assigned events, check in/out'),
  admin('Admin', 'Manage menu, charges, and incoming bookings');

  const UserRole(this.label, this.description);
  final String label;
  final String description;

  static UserRole fromString(String? value) {
    return switch (value) {
      'admin' => UserRole.admin,
      'banquet' => UserRole.banquet,
      'restaurant' => UserRole.restaurant,
      'manager' => UserRole.manager,
      'service_boy' => UserRole.serviceBoy,
      // Legacy values. Database migration (phase13) rewrites these, but
      // cached/session-bound reads may still hand us the old strings briefly.
      'user' => UserRole.customer,
      'delivery' => UserRole.serviceBoy,
      _ => UserRole.customer,
    };
  }

  /// DB enum value — matches the profiles.role check constraint.
  String get dbValue => switch (this) {
        UserRole.customer => 'customer',
        UserRole.banquet => 'banquet',
        UserRole.restaurant => 'restaurant',
        UserRole.manager => 'manager',
        UserRole.serviceBoy => 'service_boy',
        UserRole.admin => 'admin',
      };
}
