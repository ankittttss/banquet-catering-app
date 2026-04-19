enum UserRole {
  user('User', 'Plan events, pick menus, place bookings'),
  admin('Admin', 'Manage menu, charges, and incoming bookings'),
  delivery('Delivery Partner', 'Pick up and deliver assigned orders');

  const UserRole(this.label, this.description);
  final String label;
  final String description;

  static UserRole fromString(String? value) {
    return switch (value) {
      'admin' => UserRole.admin,
      'delivery' => UserRole.delivery,
      _ => UserRole.user,
    };
  }

  String get dbValue => name; // 'user' | 'admin' | 'delivery'
}
